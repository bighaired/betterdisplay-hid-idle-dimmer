#!/bin/bash
# Removes only this utility, not BetterDisplay or Hammerspoon.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CONF="$HOME/.hammerspoon"
INIT="$CONF/init.lua"
mkdir -p "$CONF"
touch "$CONF/.betterdisplay_idle_dim.disabled"
# First restore the saved brightness (or safe fallback) before removing code.
if [[ -f "$CONF/betterdisplay_idle_dim.snapshot" ]]; then
  "$HERE/restore-brightness.sh"
else
  echo 'No saved brightness snapshot found. If screens are dark, use Ctrl+Option+Cmd+R first.'
fi
if [[ -f "$INIT" ]]; then
  cp "$INIT" "$INIT.backup-uninstall-$(date +%Y%m%d-%H%M%S)"
  TEMP="$(mktemp "$CONF/.init_without_dim.XXXXXXXX")"
  awk '
    $0 == "-- BEGIN betterdisplay-hid-idle-dimmer" {inblock=1;next}
    $0 == "-- END betterdisplay-hid-idle-dimmer" {inblock=0;next}
    inblock {next}
    /^[[:space:]]*require\(["\047]betterdisplay_idle_dim["\047]\)[[:space:]]*$/ {next}
    {print}
  ' "$INIT" > "$TEMP"
  cat "$TEMP" > "$INIT"
  rm -f "$TEMP"
fi
rm -f "$CONF/betterdisplay_idle_dim.lua" "$CONF/physical_idle_query" \
      "$CONF/.betterdisplay_idle_dim.disabled" "$CONF/betterdisplay_idle_dim.snapshot"
echo 'Utility files and init.lua import removed. Backups/log preserved for diagnosis.'
echo 'NOW: Hammerspoon -> Reload Config (or quit/relaunch) to stop loaded timers.'
echo 'Other apps/configurations have not been removed.'
