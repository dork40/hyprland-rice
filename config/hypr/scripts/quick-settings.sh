#!/usr/bin/env bash
# Super+G: toggle the quick-settings popup. A hidden resident copy answers SIGUSR1 instantly;
# start it if it is not running yet (also launched at login from hyprland.lua).
if pkill -USR1 -f '^python3 .*quick-settings\.py'; then exit 0; fi
LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so exec python3 ~/.config/hypr/scripts/quick-settings.py
