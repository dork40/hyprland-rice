#!/usr/bin/env bash
# Volume / mic / brightness keys. Uses SwayOSD's pop-up when it is installed, plain commands plus a notification otherwise.
# Takes the same arguments as swayosd-client, e.g.  osd.sh --output-volume raise
if command -v swayosd-client >/dev/null 2>&1; then exec swayosd-client "$@"; fi
note() { notify-send -t 1200 -h string:x-dunst-stack-tag:osd -h "int:value:$2" "$1" 2>/dev/null; }
vol() { wpctl get-volume "$1" 2>/dev/null | awk '{printf "%d", $2 * 100}'; }
case "$1 $2" in
    "--output-volume raise")       wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+; note "Volume" "$(vol @DEFAULT_AUDIO_SINK@)" ;;
    "--output-volume lower")       wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-;        note "Volume" "$(vol @DEFAULT_AUDIO_SINK@)" ;;
    "--output-volume mute-toggle") wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle;       note "Volume (mute toggled)" "$(vol @DEFAULT_AUDIO_SINK@)" ;;
    "--input-volume mute-toggle")  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle;     note "Microphone (mute toggled)" "$(vol @DEFAULT_AUDIO_SOURCE@)" ;;
    "--brightness raise")          brightnessctl -q set 5%+;                          note "Brightness" "$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %)" ;;
    "--brightness lower")          brightnessctl -q set 5%-;                          note "Brightness" "$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %)" ;;
esac
