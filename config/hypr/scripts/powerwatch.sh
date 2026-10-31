#!/usr/bin/env bash
# Background watcher: turns turbo and game mode off when the charger is unplugged.
ac=/sys/class/power_supply/ADP0/online
rt=${XDG_RUNTIME_DIR:-/tmp}
prev=$(<"$ac")
while sleep 3; do
    cur=$(<"$ac")
    if [ "$prev" = 1 ] && [ "$cur" = 0 ]; then
        [ -f "$rt/turbomode" ] && ~/.config/hypr/scripts/asus-profile.sh turbo >/dev/null
        [ -f "$rt/gamemode" ] && ~/.config/hypr/scripts/asus-profile.sh game >/dev/null
        rm -f "$rt/autogame"
        notify-send -t 3000 "On battery" "Turbo and game mode switched off"
    fi
    prev=$cur
done
