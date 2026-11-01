#!/bin/bash
# <xbar.title>RMK Battery Center</xbar.title>
# <xbar.version>0.1.0</xbar.version>
# <xbar.desc>Read both split keyboard batteries through Bluetooth</xbar.desc>
set -euo pipefail
configuration="$HOME/Library/Application Support/RMK Battery Center"
name=OP36
identifier=""
left=Left
right=Right
if [[ -f "$configuration/name" ]]; then name="$(cat "$configuration/name")"; fi
if [[ -f "$configuration/identifier" ]]; then identifier="$(cat "$configuration/identifier")"; fi
if [[ -f "$configuration/left-name" ]]; then left="$(cat "$configuration/left-name")"; fi
if [[ -f "$configuration/right-name" ]]; then right="$(cat "$configuration/right-name")"; fi
bundle="$configuration/RMK Battery Center.app"
if [[ ! -d "$bundle" ]]; then
    printf '⌨ —\n---\nBuild and install RMK Battery Center first\n'
    exit 0
fi
report="$(mktemp -t rmk-battery)"
/usr/bin/open -g -n "$bundle" --args --name "$name" --id "$identifier" --left-name "$left" --right-name "$right" --output "$report" &
launcher=$!
trap 'rm -f "$report"; kill "$launcher" 2>/dev/null || true' EXIT
for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -s "$report" ]]; then
        cat "$report"
        exit 0
    fi
    /bin/sleep 0.2
done
printf '⌨ —\n---\nBattery helper did not respond — check Bluetooth permission\nRefresh | refresh=true\n'
