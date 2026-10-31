#!/usr/bin/env bash
# Screen power.
#   off    turn the screen off (used by hypridle)
#   on     turn the screen back on (used by hypridle)
#   button turn the screen off and wait; a key press wakes the screen, then the backlight comes back
dpms()   { hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })" >/dev/null; }

case "$1" in
  off) dpms off ;;
  on)  dpms on ;;
  button)
    sleep 0.6  # let the click that opened this finish so it doesn't wake the screen
    dpms off
    while hyprctl monitors | grep -q "dpmsStatus: 0"; do sleep 0.5; done
    ;;
esac
