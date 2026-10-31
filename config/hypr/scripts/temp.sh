#!/usr/bin/env bash
# CPU temperature for waybar. Right click flips Celsius/Fahrenheit.
#   (no arg)  print waybar JSON
#   unit      flip C/F
unit=${XDG_STATE_HOME:-$HOME/.local/state}/tempunit
f() { [ "$(cat "$unit" 2>/dev/null)" = F ]; }
if [ "$1" = unit ]; then
    mkdir -p "${unit%/*}"
    if f; then echo C >"$unit"; else echo F >"$unit"; fi
    pkill -RTMIN+12 waybar; exit
fi
raw=""
for h in /sys/class/hwmon/hwmon*; do   # the CPU sensor is called k10temp (AMD), coretemp (Intel) or zenpower
    case $(cat "$h/name" 2>/dev/null) in k10temp|coretemp|zenpower) raw=$(cat "$h/temp1_input" 2>/dev/null); break ;; esac
done
[ -z "$raw" ] && { echo '{"text":""}'; exit; }
c=$(( raw / 1000 ))
if f; then t="$(( c * 9 / 5 + 32 ))°F"; else t="${c}°C"; fi
cls=""; [ "$c" -ge 90 ] && cls=critical
echo "{\"text\":\"󰔏 $t\",\"class\":\"$cls\",\"tooltip\":\"CPU temperature\\nRight click: switch °C/°F\"}"
