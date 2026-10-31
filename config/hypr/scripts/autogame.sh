#!/usr/bin/env bash
# Background watcher: game mode turns on when a game goes fullscreen and off when it stops.
# Only reacts to game windows (Steam games, gamescope, Windows .exe games), not videos or browsers.
rt=${XDG_RUNTIME_DIR:-/tmp}
auto=$rt/autogame; game=$rt/gamemode
sock=$rt/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock
regex='^(steam_app_.*|cs2|gamescope|.*\.exe)$'
check() {
    w=$(hyprctl activewindow -j 2>/dev/null)
    read -r fs class < <(python3 -c 'import json,sys
try: d=json.load(sys.stdin); print(d.get("fullscreen",0), d.get("class",""))
except Exception: print(0, "")' <<<"$w")
    if [ "$fs" != 0 ] && [[ $class =~ $regex ]]; then
        if [ ! -f "$game" ]; then touch "$auto"; ~/.config/hypr/scripts/asus-profile.sh game >/dev/null; fi
    elif [ -f "$auto" ]; then
        rm -f "$auto"
        [ -f "$game" ] && ~/.config/hypr/scripts/asus-profile.sh game >/dev/null
    fi
}
socat -u "UNIX-CONNECT:$sock" - | while IFS='>' read -r ev _; do
    case "$ev" in fullscreen|activewindowv2|closewindow|workspacev2) check ;; esac
done
