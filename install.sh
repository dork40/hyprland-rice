#!/usr/bin/env bash
# Installs this Hyprland rice: dependencies, configs, scripts, wallpapers and the Wardrobe style switcher.
# Works on Arch (and Arch-based), Fedora and Ubuntu/Debian.
#   ./install.sh                 install packages (asks for sudo) + copy everything
#   ./install.sh --no-packages   copy configs only
#   ./install.sh --dry-run       show what would happen, change nothing
#   ./install.sh --no-max-performance   (PC edition) skip the max CPU/GPU/fan service
set -euo pipefail

EDITION=laptop   # laptop | pc  (the pc-edition branch sets this to pc)

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP=$HOME/.config-rice-backup-$(date +%Y%m%d-%H%M%S)
PACKAGES=1; DRY=0; MAXPERF=1
for a in "$@"; do
    case $a in
        --no-packages) PACKAGES=0 ;;
        --dry-run) DRY=1 ;;
        --no-max-performance) MAXPERF=0 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done
run() { if ((DRY)); then echo "  [dry-run] $*"; else "$@"; fi; }
say() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

# ---- distro ---------------------------------------------------------------
# RICE_DISTRO=arch|fedora|debian forces it (testing). Otherwise read /etc/os-release.
if [[ -n ${RICE_DISTRO:-} ]]; then DISTRO=$RICE_DISTRO; else
    ids=" $(. /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}") "
    case $ids in
        *" arch "*) DISTRO=arch ;;
        *" fedora "*) DISTRO=fedora ;;
        *" ubuntu "*|*" debian "*) DISTRO=debian ;;
        *) DISTRO=unknown ;;
    esac
fi

# ---- package lists (names differ per distro) -------------------------------
case $DISTRO in
arch)
    CORE=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout starship ttf-jetbrains-mono-nerd
          python python-gobject gtk4 gtk4-layer-shell ffmpeg imagemagick jq curl libnotify xdg-desktop-portal-hyprland)
    EXTRA=(cliphist wl-clipboard grim slurp playerctl tesseract tesseract-data-eng btop cava udiskie
           network-manager-applet blueman polkit-kde-agent pavucontrol papirus-icon-theme breeze)
    AUR=(awww blesh-git rofimoji)
    NVIDIA=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland linux-headers) ;;
fedora)
    CORE=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gobject gtk4
          gtk4-layer-shell ffmpeg-free ImageMagick jq curl libnotify xdg-desktop-portal-hyprland fontconfig xz)
    EXTRA=(cliphist wl-clipboard grim slurp playerctl tesseract tesseract-langpack-eng btop cava udiskie
           network-manager-applet blueman polkit-kde pavucontrol papirus-icon-theme breeze-cursor-theme rofimoji)
    AUR=()
    NVIDIA=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver egl-wayland) ;;
debian)
    CORE=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gi gir1.2-gtk-4.0
          gir1.2-gtk4layershell-1.0 libgtk4-layer-shell0 ffmpeg imagemagick jq curl libnotify-bin
          xdg-desktop-portal-hyprland fontconfig xz-utils)
    EXTRA=(cliphist wl-clipboard grim slurp playerctl tesseract-ocr tesseract-ocr-eng btop cava udiskie
           network-manager-gnome blueman polkit-kde-agent-1 pavucontrol papirus-icon-theme breeze-cursor-theme rofimoji)
    AUR=()
    NVIDIA=() ;;   # Ubuntu/Debian: `ubuntu-drivers install` / nvidia-driver handled below
*)  CORE=(); EXTRA=(); AUR=(); NVIDIA=() ;;
esac
[[ $EDITION == laptop ]] && EXTRA+=(brightnessctl)

# ---- GPU detection (RICE_LSPCI lets you test with fake lspci output) ------------
gpus=${RICE_LSPCI:-$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)}
HAS_NVIDIA=0; HAS_OTHER=0
grep -qi nvidia <<<"$gpus" && HAS_NVIDIA=1
grep -Eqi '\b(amd|ati)\b|intel' <<<"$gpus" && HAS_OTHER=1

MISSING=()
has_pkg() {  # is this package available from the distro's repos?
    case $DISTRO in
        arch)   pacman -Si "$1" &>/dev/null ;;
        fedora) command -v dnf >/dev/null && dnf -q info "$1" &>/dev/null || { ((DRY)) && ! command -v dnf >/dev/null; } ;;
        debian) command -v apt-cache >/dev/null && [[ -n $(apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p' | grep -v '(none)') ]] || { ((DRY)) && ! command -v apt-cache >/dev/null; } ;;
    esac
}
pkg_install() {
    case $DISTRO in
        arch)   run sudo pacman -S --needed --noconfirm "$@" ;;
        fedora) run sudo dnf install -y "$@" ;;
        debian) run sudo apt-get install -y "$@" ;;
    esac
}

fetch() {  # fetch URL DEST
    run curl -fsSL --retry 3 -o "$2" "$1"
}
install_nerd_font() {
    fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd" && return 0
    say "Installing JetBrainsMono Nerd Font (icons in the bar need it)"
    local d="$HOME/.local/share/fonts/JetBrainsMonoNF" tmp; tmp=$(mktemp -d)
    fetch https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz "$tmp/f.tar.xz"
    run mkdir -p "$d"; run tar -xJf "$tmp/f.tar.xz" -C "$d"; run fc-cache -f "$d"; rm -rf "$tmp"
}
install_starship() {
    command -v starship >/dev/null && return 0
    say "Installing starship (prompt) from its GitHub release"
    local tmp; tmp=$(mktemp -d)
    fetch https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz "$tmp/s.tgz"
    run mkdir -p "$HOME/.local/bin"; run tar -xzf "$tmp/s.tgz" -C "$HOME/.local/bin" starship; rm -rf "$tmp"
}

# ---- packages -------------------------------------------------------------------
if ((PACKAGES)); then
    if [[ $DISTRO == unknown ]]; then
        echo "Unknown distro. Re-run with --no-packages, then install the tools in README.md by hand."; exit 1
    fi
    say "Detected distro: $DISTRO"
    case $DISTRO in
        fedora)
            say "Enabling the Hyprland COPR (Fedora's own Hyprland is too old for this config)"
            run sudo dnf install -y dnf-plugins-core
            run sudo dnf copr enable -y solopasha/hyprland ;;
        debian) run sudo apt-get update ;;
    esac
    say "Installing packages (anything your distro doesn't ship is listed at the end)"
    want=()
    for p in "${CORE[@]}" "${EXTRA[@]}"; do
        if has_pkg "$p"; then want+=("$p"); else MISSING+=("$p"); fi
    done
    ((${#want[@]})) && pkg_install "${want[@]}"
    if [[ $DISTRO == arch ]]; then
        helper=$(command -v yay || command -v paru || true)
        if [[ -n $helper ]]; then
            say "Installing AUR packages with ${helper##*/}"
            run "$helper" -S --needed --noconfirm "${AUR[@]}" || MISSING+=("${AUR[@]}")
        else
            MISSING+=("${AUR[@]}"); echo "No yay/paru found: install these from the AUR yourself: ${AUR[*]}"
        fi
    fi
    install_nerd_font
    [[ $DISTRO != arch ]] && install_starship
fi

# ---- NVIDIA ------------------------------------------------------------------------
if ((HAS_NVIDIA && PACKAGES)); then
    say "NVIDIA GPU found: installing the driver"
    case $DISTRO in
        arch)
            echo "  Open kernel modules (GTX 16xx / RTX and newer). Older cards (GTX 10xx and before) need the AUR package nvidia-580xx-dkms instead."
            pkg_install "${NVIDIA[@]}"
            run sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service ;;
        fedora)
            run sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
            pkg_install "${NVIDIA[@]}"
            echo "  The kernel module builds on first boot: wait a few minutes before rebooting twice if the screen is black." ;;
        debian)
            if command -v ubuntu-drivers >/dev/null; then run sudo ubuntu-drivers install
            else pkg_install nvidia-driver; fi ;;
    esac
    run sudo mkdir -p /etc/modprobe.d
    run sudo sh -c 'echo "options nvidia_drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia-rice.conf'
    echo "  Reboot once after install so the driver loads with modesetting."
fi

# ---- configs ------------------------------------------------------------------------
say "Backing up anything that would be overwritten -> $BACKUP"
for d in "$HERE"/config/*; do
    name=$(basename "$d")
    if [[ -e $CFG/$name ]]; then run mkdir -p "$BACKUP"; run cp -a "$CFG/$name" "$BACKUP/"; fi
done

say "Copying configs to $CFG"
run mkdir -p "$CFG"
for d in "$HERE"/config/*; do run cp -a "$d" "$CFG/"; done
run chmod +x "$CFG"/hypr/scripts/* "$CFG"/rices/wardrobe.py "$CFG"/rices/picker.py 2>/dev/null || true

if ((HAS_NVIDIA)); then
    if ((HAS_OTHER)); then
        echo "NVIDIA + integrated GPU (hybrid laptop): leaving the environment alone so the integrated GPU keeps driving the screen."
        echo "  Run a game on the NVIDIA GPU with:  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <program>"
    else
        say "NVIDIA only: writing the Hyprland NVIDIA environment"
        if ((DRY)); then echo "  [dry-run] $CFG/hypr/nvidia.lua"; else cat >"$CFG/hypr/nvidia.lua" <<'LUA'
-- written by install.sh: NVIDIA-only machine
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
LUA
        fi
    fi
fi

say "Adding the Displays app to your app launcher"
run mkdir -p "$HOME/.local/share/applications"
if ((DRY)); then echo "  [dry-run] ~/.local/share/applications/rice-displays.desktop"; else cat >"$HOME/.local/share/applications/rice-displays.desktop" <<DESK
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
fi

say "Copying wallpapers to ~/Pictures/wallpapers"
run mkdir -p "$HOME/Pictures/wallpapers"
run cp -an "$HERE"/wallpapers/. "$HOME/Pictures/wallpapers/"

if [[ $EDITION == pc ]] && ((MAXPERF)); then
    say "Installing the max-performance service (CPU/GPU full speed, fans 100%, starts at every boot)"
    run sudo install -m 755 "$HERE/pc/rice-max-performance" /usr/local/bin/rice-max-performance
    run sudo install -m 644 "$HERE/pc/rice-max-performance.service" /etc/systemd/system/rice-max-performance.service
    run sudo systemctl daemon-reload
    run sudo systemctl enable --now rice-max-performance.service
fi

say "Generating the default style (noir)"
if ((DRY)); then echo "  [dry-run] $CFG/rices/wardrobe.py apply noir"; else "$CFG/rices/wardrobe.py" apply noir || true; fi

# ---- report ------------------------------------------------------------------------
say "Dependency check"
absent=()
for c in Hyprland hyprctl waybar wofi dunst kitty swayosd-client hypridle hyprpaper wlogout starship awww cliphist \
         wl-copy grim slurp playerctl python3 ffmpeg magick convert jq curl notify-send; do
    command -v "$c" >/dev/null 2>&1 || [[ -x $HOME/.local/bin/$c ]] || absent+=("$c")
done
if ((${#absent[@]})); then
    echo "  Not found on this system: ${absent[*]}"
    echo "  (Hyprland, Waybar, kitty, wofi and dunst are the essentials. The rest add extra buttons and shortcuts;"
    echo "   awww sets the wallpaper: https://codeberg.org/LGFae/awww . Install what you want from your distro or by hand.)"
fi
if ((${#MISSING[@]})); then echo "  Not available from your distro's repos: ${MISSING[*]}"; fi
if command -v Hyprland >/dev/null && ! printf '0.56\n%s\n' "$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)" | sort -VC; then
    echo "  WARNING: this config is written for Hyprland 0.56+ (the Lua config format). Your Hyprland looks older and may not load it."
fi

cat <<MSG

Done. Log out and pick "Hyprland" at the login screen (or run: Hyprland).
  Super+Shift+R   switch rice style (Wardrobe)       Super+W   wallpapers
  Super+/         cheat sheet of every shortcut
Your old configs, if any, are in: $BACKUP
Weather: set WEATHER_LOCATION="City,State" in your environment to pin it (default: guessed from your IP).
MSG
if [[ $EDITION == pc ]] && ((MAXPERF)); then
    echo "Max performance is ON (fans 100%, loud on purpose). Turn it off any time:  sudo systemctl disable --now rice-max-performance"
fi
