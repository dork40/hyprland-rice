#!/usr/bin/env bash
# Max performance button for waybar: toggles turbo mode (CPU/GPU max, fans 100%, animations off).
turbo=${XDG_RUNTIME_DIR:-/tmp}/noanimmode
[ "$1" = toggle ] && { ~/.config/hypr/scripts/asus-profile.sh turbo anim >/dev/null; exit; }

if [ -f "$turbo" ]; then
    echo '{"text":"󰈸","class":"on","tooltip":"Animations off (turbo)\nClick to turn off"}'
else
    echo '{"text":"󰈸","class":"off","tooltip":"Max performance off\nClick: CPU/GPU max, fans 100%, animations off"}'
fi
