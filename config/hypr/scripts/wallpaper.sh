#!/usr/bin/env bash
# Super+W: open the wallpaper picker (press Super+W again to close it)
pkill -f '^python3 .*wallpaper-picker\.py' && exit 0
LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so exec python3 ~/.config/hypr/scripts/wallpaper-picker.py
