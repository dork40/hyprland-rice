#!/usr/bin/env bash
# Waybar: number of pending updates (pacman + AUR).
#   (no arg)  print the waybar status
#   run       update everything in a kitty window, then refresh the count
if [ "$1" = run ]; then
    kitty --title "System update" bash -c 'yay; echo; read -n1 -rsp "Done. Press any key to close"'
    pkill -RTMIN+11 waybar
    exit
fi
repo=$(checkupdates 2>/dev/null | wc -l)
aur=$(yay -Qua 2>/dev/null | wc -l)
n=$((repo + aur))
if (( n > 0 )); then
    echo "{\"text\":\"󰚰 $n\",\"class\":\"pending\",\"tooltip\":\"$repo from Arch, $aur from the AUR\\nClick to update\"}"
else
    echo "{\"text\":\"󰚰\",\"class\":\"none\",\"tooltip\":\"Everything is up to date\"}"
fi
