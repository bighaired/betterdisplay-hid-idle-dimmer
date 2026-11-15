#!/bin/bash
# Emergency recovery; supports v2.3 software snapshots and older combined snapshots.
set -euo pipefail
CONF="$HOME/.hammerspoon"
BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
[[ -x "$BD" ]] || { echo 'BetterDisplay CLI not found. Use BetterDisplay UI.' >&2; exit 1; }
SNAP="$CONF/betterdisplay_idle_dim.snapshot"
feature='softwareBrightness'
main='1.0'; other='1.0'
if [[ -f "$SNAP" ]]; then
  mode="$(awk -F= '$1=="mode" {print $2; exit}' "$SNAP")"
  if [[ "$mode" == 'software' ]]; then
    feature='softwareBrightness'
  elif [[ -z "$mode" || "$mode" == 'combined' ]]; then
    feature='combinedBrightness'  # Legacy recovery ONLY, for previous versions.
    main='0.60'; other='0.60'
  else
    echo "Unknown snapshot mode: $mode; refusing restore" >&2; exit 1
  fi
  saved_main="$(awk -F= '$1=="main" {print $2; exit}' "$SNAP")"
  saved_other="$(awk -F= '$1=="other" {print $2; exit}' "$SNAP")"
  [[ "$saved_main" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] && main="$saved_main"
  [[ "$saved_other" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] && other="$saved_other"
fi
"$BD" set -displayWithMainStatus "-$feature=$main"
"$BD" set -displayWithNonMainStatus "-$feature=$other"
echo "Restored $feature: main=$main other=$other"
echo 'Disable automatic dimming and Reload Config if necessary.'

