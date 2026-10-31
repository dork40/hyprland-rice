#!/usr/bin/env bash
# Waybar control for the idle screen-off timer (hypridle).
#   (no arg)  print the waybar status
#   toggle    turn the timer on/off
#   pick      choose the timeout with wofi (or type any number of minutes)
conf=~/.config/hypr/hypridle.conf
mins=$(( $(sed -n 's/^ *timeout = \([0-9]*\).*/\1/p' "$conf") / 60 ))

# "Off" still runs hypridle with a sleep-only config so closing the lid always locks
refresh() { pkill -RTMIN+10 waybar; }
active()  { pgrep -x hypridle >/dev/null && ! pgrep -f 'hypridle -c .*sleeponly' >/dev/null; }
stop()    { pkill -x hypridle; while pgrep -x hypridle >/dev/null; do sleep 0.1; done; }
start()   { stop; setsid -f hypridle >/dev/null 2>&1; }
start_off() { stop; setsid -f hypridle -c ~/.config/hypr/hypridle-sleeponly.conf >/dev/null 2>&1; }

case "$1" in
  toggle)
    if active; then
        start_off; notify-send -t 2000 "Screen timeout off" "The screen stays on until you turn it back on"
    else
        start; notify-send -t 2000 "Screen timeout on" "Screen turns off after $mins min idle"
    fi
    refresh ;;
  pick)
    choice=$(printf '%s minutes\n' 5 10 15 20 30 45 60 90 |
             wofi --dmenu --prompt "Screen off after… (or type minutes)" --lines 9) || exit 0
    n=${choice%% *}
    if ! [[ $n =~ ^[0-9]+$ ]] || (( n < 1 )); then
        notify-send -t 3000 "Screen timeout" "\"$choice\" isn't a number of minutes"; exit 1
    fi
    sed -i "s/^\( *timeout = \)[0-9]*/\1$(( n * 60 ))/" "$conf"
    start
    notify-send -t 2000 "Screen timeout: $n min" "Screen and keyboard light turn off after $n min idle"
    refresh ;;
  *)
    if active; then
        echo "{\"text\":\"󰾪 ${mins}m\",\"class\":\"on\",\"tooltip\":\"Screen turns off after $mins min idle\\nLeft click: turn off  ·  Right click: change time\"}"
    else
        echo "{\"text\":\"󰅶\",\"class\":\"off\",\"tooltip\":\"Screen timeout is off (screen stays on)\\nLeft click: turn on  ·  Right click: change time\"}"
    fi ;;
esac
