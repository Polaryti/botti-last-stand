"""Verify dev packaging cannot overwrite production identity or export settings."""

import importlib.util
from pathlib import Path
import tempfile
import contextlib
import io
import subprocess
import sys
from unittest.mock import patch
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_dev_build", ROOT / "tools/prepare_dev_build.py")
dev = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dev)


class DevBuildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        for name in ["project.godot", "export_presets.cfg"]:
            (self.root / name).write_bytes((ROOT / name).read_bytes())

    def tearDown(self):
        self.directory.cleanup()

    def test_separate_app_preserves_production_exports(self):
        before = (self.root / "export_presets.cfg").read_text()
        info = dev.prepare(self.root, 42, "a" * 40)
        after = (self.root / "export_presets.cfg").read_text()
        for name in ["preset.0", "preset.0.options", "preset.1", "preset.1.options"]:
            self.assertEqual(dev.section(before, name).group(1).strip(), dev.section(after, name).group(1).strip())
        self.assertEqual(info["package"], "com.botti.laststand.dev")
        self.assertEqual(info["version_code"], 100042)
        self.assertIn('custom_features="dev"', dev.section(after, "preset.2").group(1))
        options = dev.section(after, "preset.2.options").group(1)
        self.assertIn('package/unique_name="com.botti.laststand.dev"', options)
        self.assertIn("permissions/custom_permissions=PackedStringArray()", options)
        self.assertIn('release_channel="dev"', (self.root / "project.godot").read_text())

    def test_reruns_are_idempotent_and_new_builds_increment(self):
        first = dev.prepare(self.root, 42, "a" * 40)
        content = (self.root / "export_presets.cfg").read_text()
        self.assertEqual(first, dev.prepare(self.root, 42, "a" * 40))
        self.assertEqual(content, (self.root / "export_presets.cfg").read_text())
        second = dev.prepare(self.root, 43, "b" * 40)
        self.assertGreater(second["version_code"], first["version_code"])
        self.assertNotEqual(second["tag"], first["tag"])
        self.assertTrue(second["version"].startswith(first["base_version"] + "-dev."))
        self.assertEqual((self.root / "export_presets.cfg").read_text().count('name="Android Dev"'), 1)

    def test_invalid_identity_fails_without_editing_sources(self):
        before = (self.root / "project.godot").read_bytes()
        for number, commit in [(0, "a" * 40), (2_100_000_000, "a" * 40), (1, "invalid sha")]:
            with self.assertRaises(ValueError):
                dev.prepare(self.root, number, commit)
        self.assertEqual(before, (self.root / "project.godot").read_bytes())


class ImportProjectTests(unittest.TestCase):
    def test_bootstrap_errors_are_not_accepted_in_verification(self):
        spec = importlib.util.spec_from_file_location("import_project", ROOT / "tools/import_project.py")
        importer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(importer)
        for verification, expected_error in [("Imported successfully\n", False), ("SCRIPT ERROR: broken game script\n", True)]:
            with self.subTest(verification=verification), tempfile.TemporaryDirectory() as temp:
                messages = iter(["ERROR: cold custom font cache\n", verification])
                def fake_run(command, stdout, **kwargs):
                    stdout.write(next(messages))
                    return subprocess.CompletedProcess(command, 0)
                with patch.object(importer.subprocess, "run", side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()):
                    if expected_error:
                        with self.assertRaises(RuntimeError):
                            importer.import_project(sys.executable, Path(temp), Path(temp) / "import.log")
                    else:
                        importer.import_project(sys.executable, Path(temp), Path(temp) / "import.log")


if __name__ == "__main__":
    unittest.main()
