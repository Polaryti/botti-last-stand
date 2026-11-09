#!/usr/bin/env python3
"""Prepare an isolated Android development export in a disposable working copy."""

import argparse
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEV_PACKAGE = "com.botti.laststand.dev"


def section(text: str, name: str) -> re.Match:
    match = re.search(r"^\[" + re.escape(name) + r"\]\n(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if match is None:
        raise ValueError(f"Missing Godot section: {name}")
    return match


def setting(text: str, name: str, key: str, value: str) -> str:
    match = section(text, name)
    body = match.group(1)
    pattern = r"^" + re.escape(key) + r"=.*$"
    if re.search(pattern, body, re.M):
        body = re.sub(pattern, lambda _: f"{key}={value}", body, flags=re.M)
    else:
        body = body.rstrip() + f"\n{key}={value}\n\n"
    return text[:match.start(1)] + body + text[match.end(1):]


def prepare(root: Path, build_number: int, commit: str) -> dict:
    if not 1 <= build_number <= 2_099_900_000:
        raise ValueError("Build number must be a positive Android-compatible integer")
    if not re.fullmatch(r"[0-9a-f]{7,40}", commit):
        raise ValueError("Commit must be a lowercase hexadecimal Git SHA")
    project = (root / "project.godot").read_text()
    presets = (root / "export_presets.cfg").read_text()
    version_match = re.search(r'^config/version="([^"]+)"$', section(project, "application").group(1), re.M)
    if version_match is None:
        raise ValueError("Missing application version")
    base_version = version_match.group(1).split("-dev.", 1)[0]
    short = commit[:7]
    version = f"{base_version}-dev.{build_number}+{short}"
    tag = f"dev-{build_number}-{short}"
    apk_name = f"botti-last-stand-{tag}.apk"
    code = 100_000 + build_number
    project = setting(project, "application", "config/name", json.dumps("Botti's Last Stand Dev"))
    project = setting(project, "application", "config/version", json.dumps(version))
    if not re.search(r"^\[botti\]$", project, re.M):
        project = project.rstrip() + "\n\n[botti]\n\n"
    project = setting(project, "botti", "release_channel", '"dev"')

    # Clone Android's settings without changing either production export preset.
    indices = [int(i) for i in re.findall(r"^\[preset\.(\d+)\]$", presets, re.M)]
    dev_index = next((i for i in indices if re.search(r'^name="Android Dev"$', section(presets, f"preset.{i}").group(1), re.M)), max(indices) + 1)
    dev = section(presets, "preset.0").group(0).replace("[preset.0]", f"[preset.{dev_index}]", 1)
    dev += section(presets, "preset.0.options").group(0).replace("[preset.0.options]", f"[preset.{dev_index}.options]", 1)
    for key, value in {"name": '"Android Dev"', "custom_features": '"dev"', "export_path": json.dumps(f"build/dev/{apk_name}")}.items():
        dev = setting(dev, f"preset.{dev_index}", key, value)
    for key, value in {
        "package/unique_name": json.dumps(DEV_PACKAGE),
        "package/name": json.dumps("Botti's Last Stand Dev"),
        "version/code": str(code), "version/name": json.dumps(version),
        "permissions/custom_permissions": 'PackedStringArray("android.permission.REQUEST_INSTALL_PACKAGES")',
    }.items():
        dev = setting(dev, f"preset.{dev_index}.options", key, value)
    if dev_index in indices:
        for name in [f"preset.{dev_index}", f"preset.{dev_index}.options"]:
            match = section(presets, name)
            presets = presets[:match.start()] + presets[match.end():]
    presets = presets.rstrip() + "\n\n" + dev
    metadata = {"channel": "dev", "base_version": base_version, "version": version,
                "version_code": code, "package": DEV_PACKAGE, "commit": commit,
                "tag": tag, "apk_name": apk_name, "preset": "Android Dev"}
    (root / "project.godot").write_text(project)
    (root / "export_presets.cfg").write_text(presets)
    (root / "build/dev").mkdir(parents=True, exist_ok=True)
    (root / "build/dev/build-info.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-number", type=int, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--project-dir", type=Path, default=ROOT)
    args = parser.parse_args()
    metadata = prepare(args.project_dir, args.build_number, args.commit)
    print(json.dumps(metadata, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for key in ["version", "tag", "apk_name"]:
                output.write(f"{key}={metadata[key]}\n")
