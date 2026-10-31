#!/usr/bin/env bash
# Waybar sleep timer: pauses whatever is playing (Cozy, Spotify, browser...) after N minutes.
# Only you can cancel it; using the keyboard or mouse does nothing to it.
#   (no arg)  print the waybar status
#   pick      choose minutes with wofi (or cancel a running timer)
state=${XDG_RUNTIME_DIR:-/tmp}/sleep-timer
refresh() { pkill -RTMIN+12 waybar; }
cancel()  { [ -f "$state" ] && { read -r _ pid <"$state"; kill "$pid" 2>/dev/null; rm -f "$state"; }; }

case "$1" in
  pick)
    opts=$(printf '%s minutes\n' 5 10 15 20 30 45 60 90 120)
    [ -f "$state" ] && opts=$(printf 'Cancel timer\n%s' "$opts")
    choice=$(printf '%s\n' "$opts" | wofi --dmenu --prompt "Pause playback after… (or type minutes)" --lines 10) || exit 0
    if [ "$choice" = "Cancel timer" ]; then
        cancel; notify-send -t 2000 "Sleep timer cancelled"; refresh; exit
    fi
    n=${choice%% *}
    if ! [[ $n =~ ^[0-9]+$ ]] || (( n < 1 )); then
        notify-send -t 3000 "Sleep timer" "\"$choice\" isn't a number of minutes"; exit 1
    fi
    cancel
    setsid -f "$0" run $(( $(date +%s) + n * 60 )) >/dev/null 2>&1
    notify-send -t 2000 "Sleep timer: $n min" "Playback pauses at $(date -d "+$n min" '+%-I:%M %p')"
    sleep 0.2; refresh ;;
  run)
    echo "$2 $$" >"$state"
    sleep $(( $2 - $(date +%s) ))
    playerctl -a pause
    rm -f "$state"
    notify-send -t 5000 "Sleep timer" "Playback paused"
    refresh ;;
  *)
    if [ -f "$state" ]; then
        read -r end _ <"$state"
        left=$(( (end - $(date +%s) + 59) / 60 ))
        echo "{\"text\":\"󰒲 ${left}m\",\"class\":\"on\",\"tooltip\":\"Pausing playback at $(date -d "@$end" '+%-I:%M %p')\\nClick to change or cancel\"}"
    else
        echo "{\"text\":\"󰒲\",\"class\":\"off\",\"tooltip\":\"Sleep timer\\nClick to pause playback after a set time\"}"
    fi ;;
esac
