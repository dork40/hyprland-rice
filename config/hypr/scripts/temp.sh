#!/usr/bin/env bash
# CPU temperature for waybar. Right click flips Celsius/Fahrenheit (bar and MangoHud).
#   (no arg)  print waybar JSON
#   unit      flip C/F
unit=${XDG_STATE_HOME:-$HOME/.local/state}/tempunit
conf=~/.config/MangoHud/MangoHud.conf
f() { [ "$(cat "$unit" 2>/dev/null)" = F ]; }
mh() {
    sed -i '/^temp_fahrenheit$/d' "$conf"
    f && echo temp_fahrenheit >>"$conf"
}
if [ "$1" = unit ]; then
    mkdir -p "${unit%/*}"
    if f; then echo C >"$unit"; else echo F >"$unit"; fi
    mh; pkill -RTMIN+12 waybar; exit
fi
[ "$1" = apply ] && { mh; exit; }

c=$(( $(cat /sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input | head -1) / 1000 ))
if f; then t="$(( c * 9 / 5 + 32 ))°F"; else t="${c}°C"; fi
cls=""; [ "$c" -ge 90 ] && cls=critical
echo "{\"text\":\"󰔏 $t\",\"class\":\"$cls\",\"tooltip\":\"CPU temperature\\nRight click: switch °C/°F\"}"
