#!/bin/bash
# Builds and checks the Android app. Run it from anywhere. See docs/BUILDING.md for the key it needs.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ ! -f keys/signing.env ]; then
	echo "keys/signing.env is missing: see docs/BUILDING.md" >&2
	exit 1
fi
source keys/signing.env
mkdir -p build
rm -f build/botti-last-stand.apk
"$GODOT" --headless --path . --export-release Android build/botti-last-stand.apk
if command -v apksigner >/dev/null; then
	JAVA_TOOL_OPTIONS= apksigner verify build/botti-last-stand.apk
fi
if command -v aapt >/dev/null; then
	aapt dump badging build/botti-last-stand.apk | head -1
fi
ls -lh build/botti-last-stand.apk
