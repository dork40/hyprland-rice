#!/usr/bin/env bash
# Waybar control for the touchpad.
#   (no arg)  print the waybar status
#   toggle    turn the touchpad off/on
#   dwt       turn "disable while typing" on/off (acts like toggle while the touchpad is off)
dev=asup1205:00-093a:2008-touchpad
state=${XDG_RUNTIME_DIR:-/tmp}/touchpad-off   # Hyprland can't report a device's enabled state, so track it here

# While the touchpad is off, a right click turns it back on like a left click
[ "$1" = dwt ] && [ -e "$state" ] && set -- toggle

refresh() { pkill -RTMIN+14 waybar; }
dwt_on()  { hyprctl getoption input:touchpad:disable_while_typing | grep -q 'bool: true'; }

case "$1" in
  toggle)
    if [ -e "$state" ]; then
        hyprctl eval "hl.device({name=\"$dev\", accel_profile=\"adaptive\", sensitivity=0.05, tap_to_click=true, scroll_factor=1.0})" >/dev/null
        rm -f "$state"; notify-send -t 2000 "Touchpad on"
    else
        # Freeze the pointer instead of disabling the device, so a press on the pad can still click this button
        hyprctl eval "hl.device({name=\"$dev\", accel_profile=\"custom 1.0 0.0 0.0\", tap_to_click=false, scroll_factor=0.0})" >/dev/null
        touch "$state"; notify-send -t 2000 "Touchpad off" "Press the touchpad (left or right click) to turn it back on"
    fi
    refresh ;;
  dwt)
    if dwt_on; then
        hyprctl eval 'hl.config({input={touchpad={disable_while_typing=false}}})' >/dev/null
        notify-send -t 2000 "Disable while typing: off" "Touchpad keeps working while you type"
    else
        hyprctl eval 'hl.config({input={touchpad={disable_while_typing=true}}})' >/dev/null
        notify-send -t 2000 "Disable while typing: on" "Touchpad ignores touches while you type"
    fi
    refresh ;;
  *)
    if dwt_on; then dwt="on"; else dwt="off"; fi
    if [ -e "$state" ]; then
        echo "{\"text\":\"󰤳\",\"class\":\"off\",\"tooltip\":\"Touchpad is off\\nLeft click: turn on  ·  Right click: turn on\"}"
    elif [ "$dwt" = on ]; then
        echo "{\"text\":\"󰟸 󰌌\",\"class\":\"dwt\",\"tooltip\":\"Touchpad on, disabled while typing\\nLeft click: turn off  ·  Right click: stop disabling while typing\"}"
    else
        echo "{\"text\":\"󰟸\",\"class\":\"on\",\"tooltip\":\"Touchpad on\\nLeft click: turn off  ·  Right click: disable while typing\"}"
    fi ;;
esac
