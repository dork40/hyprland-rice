#!/usr/bin/env bash
# Click anywhere to copy that pixel's hex colour
c=$(hyprpicker -a -f hex) && [ -n "$c" ] && notify-send -t 3000 "Copied $c" "Colour picked from the screen"
