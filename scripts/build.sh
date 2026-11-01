#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
swift build -c release
binary="$(swift build -c release --show-bin-path)/rmk-battery"
bundle="$root/dist/RMK Battery Center.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$binary" "$bundle/Contents/MacOS/rmk-battery"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
/usr/bin/xattr -cr "$bundle"
/usr/bin/codesign --force --sign - "$bundle"
printf 'Built %s\n' "$bundle"
