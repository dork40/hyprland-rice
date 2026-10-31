#!/usr/bin/env bash
# MangoHud toggle for every app (applies to apps launched afterwards).
#   (no arg)  print waybar JSON
#   toggle    flip MANGOHUD between 1 and 0
#   apply     re-apply the saved state (run at login)
# Covers all Flatpak apps (global override) and anything launched from Hyprland.
# Native (non-Flatpak) apps also need the mangohud package installed.
state=${XDG_STATE_HOME:-$HOME/.local/state}/mangohud
mkdir -p "${state%/*}"
on() { [ "$(cat "$state" 2>/dev/null)" = 1 ]; }
apply() {
    # Drop per-app MANGOHUD settings (Steam, Roblox/Sober) so they follow the global one.
    # Edit the files directly: --unset-env would strip MANGOHUD from the app entirely.
    for f in ~/.local/share/flatpak/overrides/{com.valvesoftware.Steam,org.vinegarhq.Sober}; do
        [ -f "$f" ] && sed -i -e '/^MANGOHUD=/d' -e '/^unset-environment=MANGOHUD;$/d' "$f"
    done
    flatpak override --user --env=MANGOHUD="$1"
    hyprctl eval "hl.env(\"MANGOHUD\",\"$1\")" >/dev/null 2>&1
}

case "$1" in
  toggle)
    if on; then v=0; msg="MangoHud off"; else v=1; msg="MangoHud on"; fi
    echo $v >"$state"; apply $v
    notify-send -t 2500 "$msg" "Applies to apps you launch from now on"
    pkill -RTMIN+10 waybar
    exit ;;
  apply) apply "$(cat "$state" 2>/dev/null || echo 0)"; exit ;;
esac

if on; then
    echo '{"text":"󰍛","class":"on","tooltip":"MangoHud on (all apps) · click to turn off"}'
else
    echo '{"text":"󰍛","class":"off","tooltip":"MangoHud off · click to turn on (all apps)"}'
fi
