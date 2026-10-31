#!/usr/bin/env bash
# Screen + keyboard backlight power.
#   off    turn both off (used by hypridle)
#   on     turn both back on (used by hypridle)
#   button turn both off and wait; a key press wakes the screen, then the backlight comes back
kbd=asus::kbd_backlight

kbd_off() {
    # Only save the level if the light is on, so a second "off" can't save 0
    [ "$(brightnessctl -d $kbd get)" -gt 0 ] && brightnessctl -q -s -d $kbd set 0
}
kbd_on() { brightnessctl -q -r -d $kbd; }
dpms()   { hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })" >/dev/null; }

case "$1" in
  off) kbd_off; dpms off ;;
  on)  dpms on; kbd_on ;;
  button)
    sleep 0.6  # let the click that opened this finish so it doesn't wake the screen
    kbd_off; dpms off
    while hyprctl monitors | grep -q "dpmsStatus: 0"; do sleep 0.5; done
    kbd_on ;;
esac
