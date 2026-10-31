#!/usr/bin/env bash
# Window switcher: list every open window with its workspace, jump to the one picked
list=$(python3 -I ~/.config/hypr/scripts/windows-list.py)
[ -z "$list" ] && exit 0
pick=$(printf '%s\n' "$list" | cut -f2 | wofi --dmenu --prompt "Windows" --insensitive) || exit 0
addr=$(printf '%s\n' "$list" | awk -F'\t' -v p="$pick" '$2 == p { print $1; exit }')
[ -n "$addr" ] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
