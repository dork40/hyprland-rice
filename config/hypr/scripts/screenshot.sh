#!/usr/bin/env bash
# Screenshot with grim/slurp. Usage: screenshot.sh region|window|screen
dir=~/Pictures/Screenshots
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
case "$1" in
  region) geom=$(slurp) || exit 1; grim -g "$geom" "$file" ;;
  window) geom=$(hyprctl -j activewindow | python3 -Ic 'import json,sys; w=json.load(sys.stdin); print("%d,%d %dx%d" % (*w["at"], *w["size"]))'); grim -g "$geom" "$file" ;;
  *)      grim "$file" ;;
esac || exit 1
command -v wl-copy >/dev/null && wl-copy < "$file"
notify-send -i "$file" "Screenshot saved" "$file"
