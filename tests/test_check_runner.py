"""Exercise the runner against real child processes, including false-pass and timeout cases."""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('run_checks', ROOT / 'tools/run_checks.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def execute(self, source, suite='regressions', timeout=2):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / 'fake-godot'
            executable.write_text('#!' + sys.executable + '\n' + source)
            executable.chmod(0o755)
            with patch.object(runner, 'ROOT', root), contextlib.redirect_stdout(io.StringIO()):
                return runner.run(suite, str(executable), 'coop', timeout)

    def test_only_completed_nonempty_clean_results_pass(self):
        for output, expected in [('RESULT: 2 checks, 0 failures', True),
                                 ('RESULT: 0 checks, 0 failures', False),
                                 ('RESULT: 2 checks, 1 failures', False),
                                 ('RESULT: 2 checks, 0 failures\nSCRIPT ERROR: broken', False),
                                 ('Started', False)]:
            with self.subTest(output=output):
                self.assertEqual(self.execute('print(' + repr(output) + ')\n'), expected)

    def test_success_summary_does_not_hide_failed_exit(self):
        self.assertFalse(self.execute("print('RESULT: 2 checks, 0 failures')\nraise SystemExit(1)\n"))

    def test_timeout_is_bounded_and_reported_as_failure(self):
        self.assertFalse(self.execute('import time\ntime.sleep(10)\n', timeout=0.1))

    def test_host_must_be_ready_before_client_is_started(self):
        self.assertFalse(self.execute("print('RESULT: 1 checks, 0 failures')\n", suite='network'))
