#!/usr/bin/env bash
# Runs INSIDE the VM as user "rice": does what a brand-new user does (get the rice, ./install.sh), then checks the result.
set -uo pipefail
cd ~
. /etc/os-release; echo "### OS: $PRETTY_NAME"
echo "### Hyprland before install: $(command -v Hyprland || echo none)"
if [[ -f rice.tgz ]]; then rm -rf hyprland-rice; mkdir hyprland-rice; tar -xzf rice.tgz -C hyprland-rice
else
    command -v git >/dev/null || { command -v pacman >/dev/null && sudo pacman -Sy --noconfirm git
        command -v apt-get >/dev/null && { sudo apt-get update -q; sudo apt-get install -yq git; }
        command -v dnf >/dev/null && sudo dnf install -yq git; }
    rm -rf hyprland-rice; git clone -q https://github.com/dork40/hyprland-rice
fi
cd hyprland-rice
export RICE_EDITION=pc RICE_GPU=other RICE_MAXPERF=0 DEBIAN_FRONTEND=noninteractive
time ./install.sh </dev/null
rc=$?
echo "### install.sh exit: $rc"
[[ ${PHASE:-} == first && -e /run/ostree-booted ]] && { echo "### RESULT: REBOOT-NEEDED"; exit 0; }
echo "### CHECKS"
fail=0
for c in Hyprland hyprctl waybar wofi dunst kitty hypridle wlogout starship awww cliphist wl-copy grim slurp playerctl thunar python3; do
    if command -v "$c" >/dev/null || [[ -x ~/.local/bin/$c ]]; then echo "ok   $c"; else echo "MISS $c"; fail=1; fi
done
[[ -e /usr/share/wayland-sessions/hyprland.desktop ]] && echo "ok   hyprland session file" || { echo "MISS session file"; fail=1; }
grep -qi 'JetBrainsMono Nerd' < <(fc-list) && echo "ok   nerd font" || { echo "MISS nerd font"; fail=1; }
[[ -f ~/.config/hypr/hyprland.lua && -f ~/.config/hypr/rice.lua ]] && echo "ok   configs + generated rice.lua" || { echo "MISS configs"; fail=1; }
python3 -c 'import gi; gi.require_version("Gtk4LayerShell","1.0"); from gi.repository import Gtk4LayerShell' 2>/dev/null \
    && echo "ok   gtk4-layer-shell (Wardrobe/Welcome apps)" || { echo "MISS gtk4-layer-shell python binding"; fail=1; }
echo "### Hyprland version: $(Hyprland --version 2>/dev/null | head -1)"
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua 2>&1 | grep -E 'config ok|rror' | head -5
echo "### RESULT: $([[ $rc == 0 && $fail == 0 ]] && echo PASS || echo FAIL)"
