"""Guard the promotion boundary and exported production APK identity."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('production_check', ROOT / 'tools/check_production_build.py')
production = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(production)

class ProductionBuildTests(unittest.TestCase):
    def test_production_sources_and_artifact_agree(self):
        version = production.verify()
        code = production.read_settings(ROOT / 'export_presets.cfg').getint('preset.0.options', 'version/code')
        good = f"package: name='com.botti.laststand' versionCode='{code}' versionName='{version}'\nuses-permission: name='android.permission.REQUEST_INSTALL_PACKAGES'\n"
        self.assertEqual(production.verify(badging=good), version)
        for bad in [good.replace('com.botti.laststand', 'com.botti.laststand.dev'), good.replace(f"versionCode='{code}'", "versionCode='100023'"), good + 'application-debuggable\n', good.replace('REQUEST_INSTALL_PACKAGES', 'INTERNET')]:
            with self.subTest(artifact=bad), self.assertRaises(ValueError):
                production.verify(badging=bad)

    def test_dev_channel_and_features_block_publication(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ['project.godot', 'export_presets.cfg']:
                (root / name).write_bytes((ROOT / name).read_bytes())
            for file, old, new in [('project.godot', 'release_channel="production"', 'release_channel="dev"'), ('export_presets.cfg', 'custom_features=""', 'custom_features="dev"'), ('export_presets.cfg', 'tests/*,tools/*,keys/*,docs/*', '')]:
                path = root / file
                original = path.read_text()
                path.write_text(original.replace(old, new, 1))
                with self.subTest(setting=old), self.assertRaises(ValueError):
                    production.verify(root)
                path.write_text(original)

class ReleaseGateTests(unittest.TestCase):
    def test_only_latest_success_for_this_main_commit_releases(self):
        spec = importlib.util.spec_from_file_location('release_gate', ROOT / 'tools/wait_for_validation.py')
        gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gate)
        good = dict(id=1, head_sha='release', event='push', head_branch='main', status='completed', conclusion='success', html_url='checks')
        self.assertTrue(gate.verdict([good], 'release'))
        self.assertFalse(gate.verdict([good], 'different'))
        self.assertFalse(gate.verdict([dict(good, head_branch='dev')], 'release'))
        self.assertFalse(gate.verdict([dict(good, status='in_progress', conclusion=None)], 'release'))
        for conclusion in ['failure', 'cancelled', 'timed_out']:
            with self.subTest(result=conclusion), self.assertRaises(RuntimeError):
                gate.verdict([good, dict(good, id=2, conclusion=conclusion)], 'release')
