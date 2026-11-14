#!/bin/bash
# Standalone macOS installer. Does not use sudo or alter display brightness.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CONF="$HOME/.hammerspoon"
BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"

[[ "$(uname -s)" == "Darwin" ]] || { echo 'macOS is required.' >&2; exit 1; }
[[ -x "$BD" ]] || { echo 'BetterDisplay CLI not found. Install BetterDisplay and enable CLI access.' >&2; exit 1; }
[[ -d /Applications/Hammerspoon.app ]] || { echo 'Install Hammerspoon first.' >&2; exit 1; }
command -v xcrun >/dev/null || { echo 'Install Apple Command Line Tools: xcode-select --install' >&2; exit 1; }
SDK="$(xcrun --sdk macosx --show-sdk-path)" || { echo 'macOS SDK not found. Install Command Line Tools.' >&2; exit 1; }
[[ -f "$SDK/System/Library/Frameworks/CoreGraphics.framework/Headers/CoreGraphics.h" ]] || { echo 'CoreGraphics.h missing from macOS SDK.' >&2; exit 1; }

mkdir -p "$CONF"
TMP="$(mktemp "$CONF/.physical_idle_query.XXXXXXXX")"
trap 'rm -f "$TMP"' EXIT
xcrun --sdk macosx clang -isysroot "$SDK" -O2 -Wall -Wextra \
  "$HERE/physical_idle_query.c" -framework CoreGraphics -o "$TMP"
chmod 755 "$TMP"
"$TMP" --both

# Validate both displays before touching Hammerspoon files.
for selector in -displayWithMainStatus -displayWithNonMainStatus; do
  value="$("$BD" get "$selector" -combinedBrightness)" || { echo "Brightness query failed: $selector" >&2; exit 1; }
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Invalid combined brightness: $value" >&2; exit 1; }
  echo "$selector: $value"
done

stamp="$(date +%Y%m%d-%H%M%S)"
for name in betterdisplay_idle_dim.lua physical_idle_query init.lua; do
  [[ ! -f "$CONF/$name" ]] || cp "$CONF/$name" "$CONF/$name.backup-$stamp"
done
[[ -f "$CONF/init.lua" ]] || touch "$CONF/init.lua"
cp "$TMP" "$CONF/physical_idle_query"
chmod 755 "$CONF/physical_idle_query"
cp "$HERE/betterdisplay_idle_dim.lua" "$CONF/betterdisplay_idle_dim.lua"
if ! grep -Fq 'require("betterdisplay_idle_dim")' "$CONF/init.lua" && \
   ! grep -Fq "require('betterdisplay_idle_dim')" "$CONF/init.lua"; then
  printf '\n-- BEGIN betterdisplay-hid-idle-dimmer\nrequire("betterdisplay_idle_dim")\n-- END betterdisplay-hid-idle-dimmer\n' >> "$CONF/init.lua"
fi
printf '\nInstalled. Existing files were backed up using timestamp %s.\n' "$stamp"
echo 'Next: Hammerspoon menu -> Reload Config.'
echo 'Test FIRST with IDLE_SECONDS=15 and DIM_LEVEL=0.05 before enabling 600/0.'
echo 'Emergency: Control + Option + Command + R (restores brightness; 30 minute pause).'
echo 'Disable: bash disable.sh; uninstall: bash uninstall.sh (see README).'
