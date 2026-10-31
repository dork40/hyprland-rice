#!/usr/bin/env bash
# Busiest GPU's usage and temperature for waybar.
best=-1
for d in /sys/class/drm/card[0-9]/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    b=$(<"$d/gpu_busy_percent")
    if [ "$b" -gt "$best" ]; then best=$b; t=$(cat "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); fi
done
if command -v nvidia-smi >/dev/null; then   # NVIDIA: usage + temperature, used when it is the busiest GPU
    IFS=', ' read -r nb nt < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [ -n "$nb" ] && [ "$nb" -gt "$best" ]; then best=$nb; t=$(( nt * 1000 )); fi
fi
[ "$best" -lt 0 ] && { echo '{"text":""}'; exit; }
t=$(( ${t:-0} / 1000 ))
if [ "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/tempunit" 2>/dev/null)" = F ]; then tt="$(( t * 9 / 5 + 32 ))°F"; else tt="${t}°C"; fi
cls=""; [ "$best" -ge 90 ] && cls=critical
echo "{\"text\":\"󰢮 $best%\",\"class\":\"$cls\",\"tooltip\":\"GPU: $best% busy, $tt\"}"
