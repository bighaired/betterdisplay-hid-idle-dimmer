#!/bin/bash
set -euo pipefail
CONF="$HOME/.hammerspoon"
mkdir -p "$CONF"
touch "$CONF/.betterdisplay_idle_dim.disabled"
echo 'Disabled marker created. In Hammerspoon select Reload Config.'
echo 'Reloading restores saved brightness before stopping auto dimming.'
echo 'If screens are dark, press Ctrl+Option+Cmd+R before reloading.'
