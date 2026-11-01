#!/bin/bash
set -euo pipefail
if [[ $# -ne 1 || ! -d "$1" ]]; then
    printf 'Usage: %s /path/to/SwiftBar/plugins\n' "$0" >&2
    exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="$HOME/Library/Application Support/RMK Battery Center"
if [[ ! -d "$root/dist/RMK Battery Center.app" ]]; then
    printf 'Run scripts/build.sh before installation\n' >&2
    exit 1
fi
mkdir -p "$configuration"
/usr/bin/ditto --norsrc --noextattr "$root/dist/RMK Battery Center.app" "$configuration/RMK Battery Center.app"
/usr/bin/codesign --verify --strict "$configuration/RMK Battery Center.app"
if [[ ! -f "$configuration/name" ]]; then printf 'OP36\n' > "$configuration/name"; fi
if [[ ! -f "$configuration/left-name" ]]; then printf 'Left\n' > "$configuration/left-name"; fi
if [[ ! -f "$configuration/right-name" ]]; then printf 'Right\n' > "$configuration/right-name"; fi
cp "$root/plugins/rmk-battery.1m.sh" "$1/rmk-battery.1m.sh"
chmod +x "$1/rmk-battery.1m.sh"
printf 'Installed the helper and SwiftBar plugin\n'
