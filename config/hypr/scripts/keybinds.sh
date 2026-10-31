#!/usr/bin/env bash
# Searchable cheat sheet of every shortcut
wofi --dmenu --prompt "Search shortcuts" --width 640 --lines 20 < ~/.config/hypr/keybinds.txt >/dev/null
