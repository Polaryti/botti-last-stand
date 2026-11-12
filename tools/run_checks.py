#!/usr/bin/env python3
"""Run Godot checks with isolated saves, bounded runtime and strict error reporting."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"(?:SCRIPT ERROR:|SHADER ERROR:|^ERROR:|\bFAIL:)", re.MULTILINE)
RESULT = re.compile(r"RESULT: (\d+) checks, (\d+) failures")


BOARD = ROOT / "server" / "leaderboard"
# Only for the local boards these checks start; tests/board_test.gd uses the same one.
TEST_ADMIN_KEY = "local-checks-admin-key-not-a-secret"


def start_boards(temporary: str, logs: Path) -> tuple[list, list[str]]:
    """Local copies of the production and dev boards, each with its own empty database."""
    wrangler = BOARD / "node_modules" / ".bin" / "wrangler"
    if not wrangler.exists():
        raise RuntimeError("Run `npm ci` in server/leaderboard first")
    processes, urls = [], []
    for env, port in [("production", 8971), ("dev", 8972)]:
        state = Path(temporary) / f"board-{env}"
        subprocess.run([str(wrangler), "d1", "migrations", "apply", "DB", "--env", env, "--local", "--persist-to", str(state)],
                       cwd=BOARD, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, env=dict(os.environ, CI="1"))
        log = (logs / f"board-{env}.log").open("w", encoding="utf-8")
        processes.append((subprocess.Popen([str(wrangler), "dev", "--env", env, "--local", "--ip", "127.0.0.1", "--port", str(port),
                                            "--persist-to", str(state), "--show-interactive-dev-session=false",
                                            "--var", "ADMIN_KEY:" + TEST_ADMIN_KEY],
                                           cwd=BOARD, stdout=log, stderr=subprocess.STDOUT), log))
        urls.append(f"http://127.0.0.1:{port}")
    deadline = time.monotonic() + 90
    for url in urls:
        while True:
            try:
                with urllib.request.urlopen(url + "/v1/health", timeout=2) as answer:
                    if answer.status == 200:
                        break
            except OSError:
                pass
            if time.monotonic() > deadline:
                raise RuntimeError("A local board did not start; see " + str(logs))
            time.sleep(0.3)
    return processes, urls


def run(suite: str, godot: str, mode: str, timeout: int, group: str = "all", case: str = "") -> bool:
    logs = ROOT / "build" / "checks" / f"{suite}-{(case or group) if suite == 'gameplay' else mode}" / str(time.time_ns())
    logs.mkdir(parents=True, exist_ok=True)
    roles = ["host", "client"] if suite == "network" else [suite]
    processes = []
    deadline = time.monotonic() + timeout
    problem = ""
    boards = []
    with tempfile.TemporaryDirectory(prefix="botti-checks-") as temporary:
        try:
            if suite == "board":
                boards, board_urls = start_boards(temporary, logs)
            for role in roles:
                profile = Path(temporary) / role
                profile.mkdir()
                env = dict(os.environ, XDG_DATA_HOME=str(profile))
                # Linux/CI profiles must not share progress or settings.
                command = [godot, "--headless", "--path", str(ROOT)]
                scene = {"network": "net_test", "gameplay": "test_game", "rework": "rework", "features": "dev_features", "board": "board_test", "creatures": "creatures"}.get(suite, "regressions")
                # Fixed steps make the game's clock outrun the real one; the board answers in real time.
                if suite not in ("network", "board"):
                    command.extend(["--fixed-fps", "240"])
                command.append(f"res://tests/{scene}.tscn")
                if suite == "network":
                    command.extend(["--", role, mode])
                elif suite == "gameplay":
                    command.extend(["--", "case=" + case] if case else ["--", "group=" + group])
                elif suite == "board":
                    # A production game against the production board, and the dev board as the wrong one.
                    command.extend(["--", "url=" + board_urls[0], "other=" + board_urls[1]])
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
            for process, log in boards:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                log.close()
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
    parser.add_argument("suite", choices=["regressions", "gameplay", "network", "rework", "features", "board", "creatures"])
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--mode", default="coop", choices=["coop", "ffa", "teams", "fort", "mists", "bots", "botsffa", "ride", "chariot", "room", "commander", "bandit", "cartographer", "mesenlla"])
    parser.add_argument("--case", default="", help="Run one named gameplay method")
    parser.add_argument("--group", default="all", choices=["all", "core", "recent", "legacy", "classes", "world"])
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    raise SystemExit(0 if run(args.suite, args.godot, args.mode, args.timeout, args.group, args.case) else 1)
