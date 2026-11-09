#!/usr/bin/env python3
"""Bootstrap a cold Godot cache, then require an error-free verification import."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR:|SHADER ERROR:|^ERROR:", re.MULTILINE)


def import_project(godot: str, root: Path, log: Path) -> None:
    root = root.resolve()
    godot = str(Path(shutil.which(godot) or godot).resolve())
    log.parent.mkdir(parents=True, exist_ok=True)
    # ThemeDB initializes before the importer. On a fresh checkout, its custom font's
    # .fontdata does not exist yet, even though this pass goes on to import it correctly.
    # Preserve that bootstrap log, then validate the fully imported project separately.
    command = [godot, "--headless", "--path", ".", "--editor", "--import"]
    for target, strict in [(log.with_suffix(".bootstrap.log"), False), (log, True)]:
        with target.open("w", encoding="utf-8") as output:
            result = subprocess.run(command, cwd=root, stdout=output, stderr=subprocess.STDOUT, timeout=300)
        content = target.read_text(encoding="utf-8")
        if result.returncode != 0 or (strict and ERROR.search(content)):
            print(content[-20000:])
            raise RuntimeError(f"Godot import failed; see {target}")
        print(f"{'Verified' if strict else 'Bootstrapped'} project import: {target}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project-dir", type=Path, default=ROOT)
    parser.add_argument("--log", type=Path, default=ROOT / "build/checks/import.log")
    args = parser.parse_args()
    import_project(args.godot, args.project_dir, args.log)
