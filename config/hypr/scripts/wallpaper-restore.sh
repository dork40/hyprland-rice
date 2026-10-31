#!/usr/bin/env bash
# Start awww and show the last chosen wallpaper
awww-daemon &
sleep 0.5
wp=~/.cache/current-wallpaper
[ -e "$wp" ] || wp=~/Pictures/wallpapers/noir/orbital-sunrise.jpg
awww img "$wp" --transition-type none
