#!/bin/bash
# Emergency brightness recovery if Hammerspoon hotkey is unavailable.
set -euo pipefail
CONF="$HOME/.hammerspoon"
BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
[[ -x "$BD" ]] || { echo 'BetterDisplay CLI not found. Restore brightness via BetterDisplay UI.' >&2; exit 1; }
SNAP="$CONF/betterdisplay_idle_dim.snapshot"
main='0.60'; other='0.60'
if [[ -f "$SNAP" ]]; then
  saved_main="$(awk -F= '$1=="main" {print $2; exit}' "$SNAP")"
  saved_other="$(awk -F= '$1=="other" {print $2; exit}' "$SNAP")"
  [[ "$saved_main" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] && main="$saved_main"
  [[ "$saved_other" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] && other="$saved_other"
fi
"$BD" set -displayWithMainStatus "-combinedBrightness=$main"
"$BD" set -displayWithNonMainStatus "-combinedBrightness=$other"
echo "Brightness restored/set: main=$main other=$other"
echo 'If Hammerspoon is still running this module, disable it and Reload Config.'
