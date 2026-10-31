#!/usr/bin/env bash
# Prints a short report on why Hyprland may not show up at the login screen. Send it to whoever is helping you.
hr() { printf '\n--- %s\n' "$*"; }
hr "system"
( . /etc/os-release 2>/dev/null; echo "$PRETTY_NAME  (VERSION_ID=${VERSION_ID:-?})" )
[[ -e /run/ostree-booted ]] && echo "immutable (rpm-ostree) system: yes" || echo "immutable (rpm-ostree) system: no"
hr "is Hyprland installed?"
for p in hyprland xdg-desktop-portal-hyprland waybar wofi kitty; do
    if command -v rpm >/dev/null; then rpm -q "$p" 2>&1 | head -1
    elif command -v pacman >/dev/null; then pacman -Q "$p" 2>&1 | head -1
    elif command -v dpkg >/dev/null; then dpkg -s "$p" 2>/dev/null | sed -n '1p;/^Version/p' | tr '\n' ' '; echo; fi
done
command -v Hyprland >/dev/null && Hyprland --version 2>/dev/null | head -1 || echo "Hyprland command: not found"
hr "login screen sessions (Hyprland must be in this list)"
ls /usr/share/wayland-sessions/ /usr/share/xsessions/ 2>&1
hr "login screen setup"
readlink /etc/systemd/system/display-manager.service 2>/dev/null || echo "display-manager.service: not set"
cat /var/lib/sddm/state.conf 2>/dev/null || echo "/var/lib/sddm/state.conf: none"
if command -v rpm-ostree >/dev/null && [[ -e /run/ostree-booted ]]; then
    hr "Xwayland (the swap)"
    rpm -qa 2>/dev/null | grep -i xwayland
    hr "rpm-ostree status (top of it)"
    rpm-ostree status 2>&1 | head -40
fi
hr "rice files"
ls ~/.config/hypr/hyprland.lua ~/.config/hypr/rice.lua ~/.config/hypr/monitors.lua 2>&1 | head -5
hr "graphics"
lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | cut -c1-110
echo
echo "Done. Send a photo or copy of everything above."
