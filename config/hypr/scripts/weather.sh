#!/usr/bin/env bash
# Waybar weather from wttr.in for a fixed location, in °F
# Retries a few times, and falls back to the last good reading so the module never goes blank.
loc="${WEATHER_LOCATION:-}"   # empty = wttr.in guesses from your IP; set WEATHER_LOCATION=City,State to pin it
cache=${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather.json
for try in 1 2 3; do
    now=$(curl -sf -m 10 "https://wttr.in/$loc?format=%c|%t|%C&u" | tr -d '+') && [ -n "$now" ] && break
    now=""; sleep 3
done
if [ -z "$now" ]; then
    cat "$cache" 2>/dev/null || echo '{"text":"","class":"offline"}'
    exit
fi
IFS='|' read -r icon temp cond <<<"$now"
fc=$(curl -sf -m 10 "https://wttr.in/$loc?format=%c+%t+(feels+%f),+%C,+wind+%w,+humidity+%h&u" | tr -d '+')
out="{\"text\":\"${icon// /} ${temp}\",\"tooltip\":\"Weather: ${fc:-$cond}\\nClick for the 3-day forecast\"}"
mkdir -p "${cache%/*}"; echo "$out" >"$cache"; echo "$out"
