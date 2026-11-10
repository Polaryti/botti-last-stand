"""A release must pass validation on its own branch and exact commit."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("validation_gate", Path(__file__).resolve().parents[1] / "tools/wait_for_validation.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class ValidationGateTests(unittest.TestCase):
    def run_record(self, branch="dev", commit="abc", conclusion="success", status="completed"):
        return {"id": 1, "head_branch": branch, "head_sha": commit, "event": "push", "status": status, "conclusion": conclusion, "html_url": "https://github.com/example/run"}

    def test_branch_and_commit_must_match(self):
        self.assertTrue(gate.verdict([self.run_record()], "abc", "dev"))
        self.assertFalse(gate.verdict([self.run_record()], "abc", "main"))
        self.assertFalse(gate.verdict([self.run_record(commit="older")], "abc", "dev"))

    def test_pending_validation_waits(self):
        self.assertFalse(gate.verdict([self.run_record(status="in_progress", conclusion=None)], "abc", "dev"))

    def test_failed_validation_blocks_publication(self):
        with self.assertRaises(RuntimeError):
            gate.verdict([self.run_record(conclusion="failure")], "abc", "dev")

    def test_production_default_is_preserved(self):
        self.assertTrue(gate.verdict([self.run_record(branch="main")], "abc"))
