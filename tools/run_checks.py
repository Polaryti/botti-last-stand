#!/usr/bin/env python3
"""Run Godot checks with isolated saves, bounded runtime and strict error reporting."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"(?:SCRIPT ERROR:|SHADER ERROR:|^ERROR:|\bFAIL:)", re.MULTILINE)
RESULT = re.compile(r"RESULT: (\d+) checks, (\d+) failures")


def run(suite: str, godot: str, mode: str, timeout: int, group: str = "all", case: str = "") -> bool:
    logs = ROOT / "build" / "checks" / f"{suite}-{(case or group) if suite == 'gameplay' else mode}" / str(time.time_ns())
    logs.mkdir(parents=True, exist_ok=True)
    roles = ["host", "client"] if suite == "network" else [suite]
    processes = []
    deadline = time.monotonic() + timeout
    problem = ""
    with tempfile.TemporaryDirectory(prefix="botti-checks-") as temporary:
        try:
            for role in roles:
                profile = Path(temporary) / role
                profile.mkdir()
                env = dict(os.environ, XDG_DATA_HOME=str(profile))
                # Linux/CI profiles must not share progress or settings.
                command = [godot, "--headless", "--path", str(ROOT)]
                scene = "net_test" if suite == "network" else "test_game" if suite == "gameplay" else "rework" if suite == "rework" else "dev_features" if suite == "features" else "regressions"
                if suite != "network":
                    command.extend(["--fixed-fps", "240"])
                command.append(f"res://tests/{scene}.tscn")
                if suite == "network":
                    command.extend(["--", role, mode])
                elif suite == "gameplay":
                    command.extend(["--", "case=" + case] if case else ["--", "group=" + group])
                log = (logs / f"{role}.log").open("w", encoding="utf-8")
                process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                processes.append((role, process, log))
                if suite == "network" and role == "host":
                    # The host's menu briefly searches on DISCOVERY_PORT before it starts
                    # hosting. Unlike two phones, these processes share a network namespace.
                    # Start the client only once that discovery socket has been released.
                    ready_by = min(deadline, time.monotonic() + 60)
                    while "NET_TEST_HOST_READY" not in (logs / "host.log").read_text(encoding="utf-8"):
                        if process.poll() is not None:
                            raise RuntimeError("Host exited before becoming ready; see " + str(logs / "host.log"))
                        if time.monotonic() >= ready_by:
                            raise TimeoutError("Host did not become ready; see " + str(logs / "host.log"))
                        time.sleep(0.1)
            while any(p.poll() is None for _, p, _ in processes):
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"{suite} exceeded {timeout} seconds")
                if any(p.poll() not in (None, 0) for _, p, _ in processes):
                    break
                time.sleep(0.1)
        except (OSError, RuntimeError, TimeoutError) as error:
            problem = str(error)
            print(problem)
        finally:
            for _, process, log in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                log.close()
    passed = not problem
    for role, process, _ in processes:
        text = (logs / f"{role}.log").read_text(encoding="utf-8")
        results = RESULT.findall(text)
        good = process.returncode == 0 and bool(results) and all(int(checks) > 0 and int(failures) == 0 for checks, failures in results) and not ERROR.search(text)
        passed = passed and good
        print(f"{role}: {'PASS' if good else 'FAIL'} {results[-1] if results else 'no result'}; exit={process.returncode}; {logs / (role + '.log')}")
        if not good:
            print(text[-12000:])
    return passed


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=["regressions", "gameplay", "network", "rework", "features"])
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--mode", default="coop", choices=["coop", "ffa", "teams", "fort", "mists", "bots", "botsffa", "ride", "chariot", "room", "commander"])
    parser.add_argument("--case", default="", help="Run one named gameplay method")
    parser.add_argument("--group", default="all", choices=["all", "core", "recent", "legacy", "classes", "world"])
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    raise SystemExit(0 if run(args.suite, args.godot, args.mode, args.timeout, args.group, args.case) else 1)
