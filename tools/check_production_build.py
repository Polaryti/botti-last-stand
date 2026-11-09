#!/usr/bin/env python3
"""Reject development identity/settings before a stable export or publication."""
import argparse
import configparser
import json
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]

def read_settings(path):
    config = configparser.RawConfigParser(interpolation=None)
    config.read_string('[root]\n' + path.read_text())
    return config

def verify(root=ROOT, badging=None):
    project = read_settings(root / 'project.godot')
    presets = read_settings(root / 'export_presets.cfg')
    def value(config, section, key):
        return json.loads(config.get(section, key))
    version = value(project, 'application', 'config/version')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Production requires a stable semantic version')
    if value(project, 'application', 'config/name') != "Botti's Last Stand":
        raise ValueError('Production app name changed')
    if value(project, 'botti', 'release_channel') != 'production':
        raise ValueError('Production cannot use the dev updater')
    if '"dev"' in project.get('application', 'config/features'):
        raise ValueError('Production cannot advertise the dev feature')
    for index in (0, 1):
        section = f'preset.{index}'
        if value(presets, section, 'custom_features'):
            raise ValueError('Production export features must remain empty')
        excluded = value(presets, section, 'exclude_filter').split(',')
        if not {'tests/*', 'tools/*', 'keys/*', 'docs/*'}.issubset(excluded):
            raise ValueError('Production must exclude tests, tools, keys and review documents')
    android = 'preset.0.options'
    code = presets.getint(android, 'version/code')
    if value(presets, android, 'package/unique_name') != 'com.botti.laststand':
        raise ValueError('Production Android package changed')
    if value(presets, android, 'package/name') != "Botti's Last Stand":
        raise ValueError('Production Android label changed')
    if value(presets, android, 'version/name') != version or not 1 <= code < 100_000:
        raise ValueError('Production Android version is inconsistent or uses a dev code')
    ios = 'preset.1.options'
    if value(presets, ios, 'application/bundle_identifier') != 'com.botti.laststand':
        raise ValueError('Production iOS bundle changed')
    if value(presets, ios, 'application/short_version') != version or int(value(presets, ios, 'application/version')) != code:
        raise ValueError('Production iOS version is inconsistent')
    if badging is not None:
        first = badging.splitlines()[0]
        required = ["name='com.botti.laststand'", f"versionCode='{code}'", f"versionName='{version}'"]
        if not all(item in first for item in required) or 'application-debuggable' in badging:
            raise ValueError('Exported APK is not the expected production release')
        if 'android.permission.REQUEST_INSTALL_PACKAGES' not in badging:
            raise ValueError('Exported APK cannot hand off in-game updates to Android')
    return version

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--badging', type=Path)
    args = parser.parse_args()
    version = verify(badging=args.badging.read_text() if args.badging else None)
    print(f'Production identity and packaging verified: {version}')
