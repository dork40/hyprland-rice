#!/usr/bin/env bash
# Installs this Hyprland rice: every dependency, the configs, scripts, wallpapers and the Wardrobe style switcher.
# Works on Arch (and Arch-based), Fedora and Ubuntu/Debian. You get the whole rice.
#   ./install.sh
#   ./install.sh --no-max-performance   (PC edition only) skip the max CPU/GPU/fan service
set -euo pipefail

EDITION=laptop   # laptop | pc  (the pc-edition branch sets this to pc)

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP=$HOME/.config-rice-backup-$(date +%Y%m%d-%H%M%S)
MAXPERF=1
for a in "$@"; do
    case $a in
        --no-max-performance) MAXPERF=0 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done
say() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

# ---- distro ---------------------------------------------------------------
# RICE_DISTRO=arch|fedora|debian forces it. Otherwise read /etc/os-release.
if [[ -n ${RICE_DISTRO:-} ]]; then DISTRO=$RICE_DISTRO; else
    ids=" $(. /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}") "
    case $ids in
        *" arch "*) DISTRO=arch ;;
        *" fedora "*) DISTRO=fedora ;;
        *" ubuntu "*|*" debian "*) DISTRO=debian ;;
        *) DISTRO=unknown ;;
    esac
fi

# ---- package lists: only what the rice itself uses --------------------------------
case $DISTRO in
arch)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout starship ttf-jetbrains-mono-nerd
          python python-gobject gtk4 gtk4-layer-shell ffmpeg curl libnotify xdg-desktop-portal-hyprland thunar
          cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract tesseract-data-eng btop udiskie
          network-manager-applet blueman polkit-kde-agent pavucontrol papirus-icon-theme breeze)
    AUR=(awww rofimoji)
    NVIDIA=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland linux-headers) ;;
fedora)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gobject gtk4
          gtk4-layer-shell ffmpeg-free curl libnotify xdg-desktop-portal-hyprland thunar fontconfig xz
          cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract tesseract-langpack-eng btop udiskie
          network-manager-applet blueman polkit-kde pavucontrol papirus-icon-theme breeze-cursor-theme rofimoji)
    AUR=()
    NVIDIA=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver egl-wayland) ;;
debian)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gi gir1.2-gtk-4.0
          gir1.2-gtk4layershell-1.0 libgtk4-layer-shell0 ffmpeg curl libnotify-bin xdg-desktop-portal-hyprland thunar
          fontconfig xz-utils cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract-ocr
          tesseract-ocr-eng btop udiskie network-manager-gnome blueman polkit-kde-agent-1 pavucontrol
          papirus-icon-theme breeze-cursor-theme rofimoji)
    AUR=()
    NVIDIA=() ;;   # Ubuntu/Debian: `ubuntu-drivers install` / nvidia-driver handled below
*)  PKGS=(); AUR=(); NVIDIA=() ;;
esac
[[ $EDITION == laptop ]] && PKGS+=(brightnessctl)

# ---- GPU detection ------------------------------------------------------------------
gpus=${RICE_LSPCI:-$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)}
HAS_NVIDIA=0; HAS_OTHER=0
grep -qi nvidia <<<"$gpus" && HAS_NVIDIA=1
grep -Eqi '\b(amd|ati)\b|intel' <<<"$gpus" && HAS_OTHER=1

MISSING=()
has_pkg() {  # is this package available from the distro's repos?
    case $DISTRO in
        arch)   pacman -Si "$1" &>/dev/null ;;
        fedora) dnf -q info "$1" &>/dev/null ;;
        debian) [[ -n $(apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p' | grep -v '(none)') ]] ;;
    esac
}
pkg_install() {
    case $DISTRO in
        arch)   sudo pacman -S --needed --noconfirm "$@" ;;
        fedora) sudo dnf install -y "$@" ;;
        debian) sudo apt-get install -y "$@" ;;
    esac
}
install_nerd_font() {
    fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd" && return 0
    say "Installing JetBrainsMono Nerd Font (the bar's icons need it)"
    local d="$HOME/.local/share/fonts/JetBrainsMonoNF" tmp; tmp=$(mktemp -d)
    curl -fsSL --retry 3 -o "$tmp/f.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
    mkdir -p "$d"; tar -xJf "$tmp/f.tar.xz" -C "$d"; fc-cache -f "$d"; rm -rf "$tmp"
}
install_starship() {
    command -v starship >/dev/null && return 0
    say "Installing starship (prompt) from its GitHub release"
    local tmp; tmp=$(mktemp -d)
    curl -fsSL --retry 3 -o "$tmp/s.tgz" https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz
    mkdir -p "$HOME/.local/bin"; tar -xzf "$tmp/s.tgz" -C "$HOME/.local/bin" starship; rm -rf "$tmp"
}

# ---- packages -------------------------------------------------------------------------
if [[ $DISTRO == unknown ]]; then
    echo "I don't know this distro, so I can't install the packages for you."
    echo "Install by hand: hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout starship thunar cliphist"
    echo "  wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract btop udiskie pavucontrol blueman"
    echo "  rofimoji awww python3-gobject gtk4 gtk4-layer-shell ffmpeg curl libnotify, plus the JetBrainsMono Nerd Font."
    echo "Copying the configs anyway."
else
    say "Detected distro: $DISTRO"
    case $DISTRO in
        fedora)
            say "Enabling the Hyprland COPR (Fedora's own Hyprland is too old for this config)"
            sudo dnf install -y dnf-plugins-core
            sudo dnf copr enable -y solopasha/hyprland ;;
        debian) sudo apt-get update ;;
    esac
    say "Installing packages (anything your distro doesn't ship is listed at the end)"
    want=()
    for p in "${PKGS[@]}"; do
        if has_pkg "$p"; then want+=("$p"); else MISSING+=("$p"); fi
    done
    ((${#want[@]})) && pkg_install "${want[@]}"
    if [[ $DISTRO == arch ]]; then
        helper=$(command -v yay || command -v paru || true)
        if [[ -n $helper ]]; then
            say "Installing AUR packages with ${helper##*/}"
            "$helper" -S --needed --noconfirm "${AUR[@]}" || MISSING+=("${AUR[@]}")
        else
            MISSING+=("${AUR[@]}"); echo "No yay/paru found: install these from the AUR yourself: ${AUR[*]}"
        fi
    fi
    install_nerd_font
    [[ $DISTRO != arch ]] && install_starship
fi

# ---- NVIDIA ----------------------------------------------------------------------------
if ((HAS_NVIDIA)) && [[ $DISTRO != unknown ]]; then
    say "NVIDIA GPU found: installing the driver"
    case $DISTRO in
        arch)
            echo "  Open kernel modules (GTX 16xx / RTX and newer). Older cards (GTX 10xx and before) need the AUR package nvidia-580xx-dkms instead."
            pkg_install "${NVIDIA[@]}"
            sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service ;;
        fedora)
            sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
            pkg_install "${NVIDIA[@]}"
            echo "  The kernel module builds on first boot: wait a few minutes before rebooting twice if the screen is black." ;;
        debian)
            if command -v ubuntu-drivers >/dev/null; then sudo ubuntu-drivers install
            else pkg_install nvidia-driver; fi ;;
    esac
    sudo mkdir -p /etc/modprobe.d
    sudo sh -c 'echo "options nvidia_drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia-rice.conf'
    echo "  Reboot once after install so the driver loads with modesetting."
fi

# ---- configs ----------------------------------------------------------------------------
say "Backing up anything that would be overwritten -> $BACKUP"
for d in "$HERE"/config/*; do
    name=$(basename "$d")
    if [[ -e $CFG/$name ]]; then mkdir -p "$BACKUP"; cp -a "$CFG/$name" "$BACKUP/"; fi
done

say "Copying configs to $CFG"
mkdir -p "$CFG"
for d in "$HERE"/config/*; do cp -a "$d" "$CFG/"; done
chmod +x "$CFG"/hypr/scripts/* "$CFG"/rices/*.py 2>/dev/null || true

if ((HAS_NVIDIA)); then
    if ((HAS_OTHER)); then
        echo "NVIDIA + integrated GPU (hybrid laptop): leaving the environment alone so the integrated GPU keeps driving the screen."
        echo "  Run a game on the NVIDIA GPU with:  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <program>"
    else
        say "NVIDIA only: writing the Hyprland NVIDIA environment"
        cat >"$CFG/hypr/nvidia.lua" <<'LUA'
-- written by install.sh: NVIDIA-only machine
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
LUA
    fi
fi

say "Adding the Displays app to your app launcher"
mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/rice-displays.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Displays
Comment=Resolution, refresh rate and multi-monitor layout
Exec=$CFG/rices/displays.py
Icon=preferences-desktop-display
Categories=Settings;
Terminal=false
StartupWMClass=dev.rice.Displays
DESK

say "Copying wallpapers to ~/Pictures/wallpapers"
mkdir -p "$HOME/Pictures/wallpapers"
cp -an "$HERE"/wallpapers/. "$HOME/Pictures/wallpapers/"

if [[ $EDITION == pc ]] && ((MAXPERF)); then
    say "Installing the max-performance service (CPU/GPU full speed, fans 100%, starts at every boot)"
    sudo install -m 755 "$HERE/pc/rice-max-performance" /usr/local/bin/rice-max-performance
    sudo install -m 644 "$HERE/pc/rice-max-performance.service" /etc/systemd/system/rice-max-performance.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now rice-max-performance.service
fi

say "Generating the default style (noir)"
"$CFG/rices/wardrobe.py" apply noir || true

# ---- report ------------------------------------------------------------------------------
say "Dependency check"
absent=()
for c in Hyprland hyprctl waybar wofi dunst kitty swayosd-client hypridle hyprpaper wlogout starship awww cliphist \
         wl-copy grim slurp hyprpicker wf-recorder playerctl thunar python3 ffmpeg curl notify-send; do
    command -v "$c" >/dev/null 2>&1 || [[ -x $HOME/.local/bin/$c ]] || absent+=("$c")
done
if ((${#absent[@]})); then
    echo "  Not found on this system: ${absent[*]}"
    echo "  (awww sets the wallpaper: https://codeberg.org/LGFae/awww . Install anything missing from your distro or by hand.)"
fi
if ((${#MISSING[@]})); then echo "  Not available from your distro's repos: ${MISSING[*]}"; fi
if command -v Hyprland >/dev/null && ! printf '0.56\n%s\n' "$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)" | sort -VC; then
    echo "  WARNING: this config is written for Hyprland 0.56+ (the Lua config format). Your Hyprland looks older and may not load it."
fi

cat <<MSG

Done. Log out and pick "Hyprland" at the login screen (or run: Hyprland).
  Super+Shift+R   switch rice style (Wardrobe)       Super+W   wallpapers
  Super+Shift+D   displays                           Super+F1  welcome / how to use it
  Super+/         cheat sheet of every shortcut
Your old configs, if any, are in: $BACKUP
Weather: set WEATHER_LOCATION="City,State" in your environment to pin it (default: guessed from your IP).
MSG
if [[ $EDITION == pc ]] && ((MAXPERF)); then
    echo "Max performance is ON (fans 100%, loud on purpose). Turn it off any time:  sudo systemctl disable --now rice-max-performance"
fi
