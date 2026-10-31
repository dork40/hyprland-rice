#!/usr/bin/env bash
# Installs this Hyprland rice: every dependency, the configs, scripts, wallpapers and the Wardrobe style switcher.
# Works on Arch (and Arch-based), Fedora and Ubuntu/Debian. You get the whole rice.
#   ./install.sh    asks which edition (laptop / PC) and which graphics card (NVIDIA / AMD / Intel), then installs everything
# For scripted installs: RICE_EDITION=laptop|pc  RICE_GPU=nvidia|amd|intel|hybrid-amd|hybrid-intel|other  RICE_MAXPERF=0|1
set -euo pipefail


HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP=$HOME/.config-rice-backup-$(date +%Y%m%d-%H%M%S)
for a in "$@"; do
    case $a in
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) echo "unknown option: $a (just run ./install.sh)"; exit 1 ;;
    esac
done
# Make sure this copy is the latest: if it is a git clone with no local edits, pull and restart with the new installer.
# (Set RICE_NO_UPDATE=1 to skip.)
if [[ -d $HERE/.git && -z ${RICE_UPDATED:-} && -z ${RICE_NO_UPDATE:-} ]] && command -v git >/dev/null; then
    if git -C "$HERE" diff --quiet && git -C "$HERE" diff --cached --quiet; then
        before=$(git -C "$HERE" rev-parse HEAD)
        git -C "$HERE" pull --ff-only -q 2>/dev/null || true
        if [[ $(git -C "$HERE" rev-parse HEAD) != "$before" ]]; then
            echo "Updated the installer to the latest version, restarting it..."
            RICE_UPDATED=1 exec bash "$HERE/install.sh" "$@"
        fi
    fi
fi
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


# ---- your choices: edition and graphics card --------------------------------------------
gpus=${RICE_LSPCI:-$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)}
det_nv=0; det_amd=0; det_intel=0
grep -qi nvidia <<<"$gpus" && det_nv=1
grep -Eqi '\b(amd|ati)\b' <<<"$gpus" && det_amd=1
grep -qi intel <<<"$gpus" && det_intel=1
if   ((det_nv && det_amd));   then det_gpu=hybrid-amd
elif ((det_nv && det_intel)); then det_gpu=hybrid-intel
elif ((det_nv));              then det_gpu=nvidia
elif ((det_amd));             then det_gpu=amd
elif ((det_intel));           then det_gpu=intel
else det_gpu=other; fi
if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then det_edition=laptop; else det_edition=pc; fi

CHOICE=""
choose() {  # choose "Question" default key1 "Label 1" key2 "Label 2" ...   -> sets CHOICE
    local q=$1 def=$2; shift 2
    local keys=() labels=() i n
    while (($#)); do keys+=("$1"); labels+=("$2"); shift 2; done
    CHOICE=$def
    [[ -r /dev/tty && -w /dev/tty ]] || return 0      # no keyboard (scripted install): use the detected default
    { echo; printf '\033[1m%s\033[0m\n' "$q"
      for i in "${!keys[@]}"; do
          printf '  %d) %s%s\n' $((i + 1)) "${labels[i]}" "$([[ ${keys[i]} == "$def" ]] && echo '   (suggested)')"
      done; } >/dev/tty
    read -r -p "Type a number and press Enter (just Enter = the suggested choice): " n </dev/tty || return 0
    if [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#keys[@]})); then CHOICE=${keys[n - 1]}; fi
}

EDITION=${RICE_EDITION:-}
if [[ $EDITION != laptop && $EDITION != pc ]]; then
    choose "Which computer is this?" "$det_edition" \
        laptop "Laptop   (battery, brightness keys, low-battery warnings)" \
        pc     "PC / desktop   (optional max-performance mode)"
    EDITION=$CHOICE
fi
GPU=${RICE_GPU:-}
case $GPU in nvidia|amd|intel|hybrid-amd|hybrid-intel|other) ;; *)
    choose "Which graphics card do you have?" "$det_gpu" \
        nvidia       "NVIDIA" \
        amd          "AMD" \
        intel        "Intel" \
        hybrid-amd   "NVIDIA + AMD   (hybrid laptop)" \
        hybrid-intel "NVIDIA + Intel   (hybrid laptop)" \
        other        "Something else / virtual machine   (skip graphics drivers)"
    GPU=$CHOICE ;;
esac
MAXPERF=0
if [[ $EDITION == pc ]]; then
    MAXPERF=${RICE_MAXPERF:-}
    if [[ $MAXPERF != 0 && $MAXPERF != 1 ]]; then
        choose "Turn on max-performance mode? (CPU/GPU at full speed, fans at 100%, starts at every boot; loud)" yes \
            yes "Yes" no "No"
        [[ $CHOICE == yes ]] && MAXPERF=1 || MAXPERF=0
    fi
fi
HAS_NVIDIA=0; HAS_OTHER=0
case $GPU in
    nvidia) HAS_NVIDIA=1 ;;
    hybrid-amd|hybrid-intel) HAS_NVIDIA=1; HAS_OTHER=1 ;;
    amd|intel) HAS_OTHER=1 ;;
esac
say "Installing the $EDITION edition, graphics: $GPU"

# Immutable Fedora (Bazzite, Silverblue, Kinoite, Aurora): dnf is blocked, packages are layered with rpm-ostree
ATOMIC=0
[[ $DISTRO == fedora && ( -e /run/ostree-booted || -n ${RICE_ATOMIC:-} ) ]] && ATOMIC=1

# ---- package lists: only what the rice itself uses --------------------------------
case $DISTRO in
arch)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout starship ttf-jetbrains-mono-nerd
          python python-gobject gtk4 gtk4-layer-shell ffmpeg curl libnotify xdg-desktop-portal-hyprland thunar sddm
          cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract tesseract-data-eng btop udiskie
          network-manager-applet blueman polkit-kde-agent pavucontrol papirus-icon-theme breeze)
    AUR=(awww rofimoji)
    NVIDIA=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland linux-headers) ;;
fedora)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gobject gtk4
          gtk4-layer-shell ffmpeg-free curl libnotify xdg-desktop-portal-hyprland thunar sddm fontconfig xz
          cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract tesseract-langpack-eng btop udiskie
          network-manager-applet blueman polkit-kde pavucontrol papirus-icon-theme breeze-cursor-theme rofimoji awww)
    AUR=()
    NVIDIA=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver egl-wayland) ;;
debian)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout python3 python3-gi gir1.2-gtk-4.0
          gir1.2-gtk4layershell-1.0 libgtk4-layer-shell0 ffmpeg curl libnotify-bin xdg-desktop-portal-hyprland thunar sddm
          fontconfig xz-utils cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract-ocr
          tesseract-ocr-eng btop udiskie network-manager-gnome blueman polkit-kde-agent-1 pavucontrol
          papirus-icon-theme breeze-cursor-theme rofimoji)
    AUR=()
    NVIDIA=() ;;   # Ubuntu/Debian: `ubuntu-drivers install` / nvidia-driver handled below
*)  PKGS=(); AUR=(); NVIDIA=() ;;
esac
[[ $EDITION == laptop ]] && PKGS+=(brightnessctl)
# graphics user-space (Vulkan/video acceleration); NVIDIA's own driver is handled in its own step below
if ((ATOMIC)); then :   # immutable images already include their graphics stack
else
    case $DISTRO:$GPU in
        arch:amd|arch:hybrid-amd)       PKGS+=(mesa vulkan-radeon libva-mesa-driver) ;;
        arch:intel|arch:hybrid-intel)   PKGS+=(mesa vulkan-intel intel-media-driver) ;;
        fedora:amd|fedora:hybrid-amd|fedora:intel|fedora:hybrid-intel) PKGS+=(mesa-dri-drivers mesa-vulkan-drivers) ;;
        debian:amd|debian:hybrid-amd)   PKGS+=(mesa-vulkan-drivers libgl1-mesa-dri) ;;
        debian:intel|debian:hybrid-intel) PKGS+=(mesa-vulkan-drivers libgl1-mesa-dri intel-media-va-driver) ;;
    esac
fi

# Fedora: which Hyprland COPR has packages for this Fedora version? (COPRs drop old Fedora versions, so try a few)
COPR=""; FEDORA_VER=""
pick_copr() {
    FEDORA_VER=$(. /etc/os-release; echo "${VERSION_ID:-$(rpm -E %fedora 2>/dev/null)}")
    local c o p
    for c in solopasha/hyprland pm4rcin/Hyprland; do
        o=${c%/*}; p=${c#*/}
        if curl -fsI -o /dev/null "https://copr.fedorainfracloud.org/coprs/$o/$p/repo/fedora-$FEDORA_VER/$o-$p-fedora-$FEDORA_VER.repo"; then
            COPR=$c; return 0
        fi
    done
    return 1
}

MISSING=(); SKIPPED=()
# package -> the command it provides, so a hand-built or differently packaged tool also counts as "already there"
declare -A CMD_OF=([hyprland]=Hyprland [waybar]=waybar [wofi]=wofi [dunst]=dunst [kitty]=kitty [swayosd]=swayosd-server
    [hypridle]=hypridle [hyprpaper]=hyprpaper [wlogout]=wlogout [starship]=starship [thunar]=thunar [cliphist]=cliphist
    [wl-clipboard]=wl-copy [grim]=grim [slurp]=slurp [hyprpicker]=hyprpicker [wf-recorder]=wf-recorder [playerctl]=playerctl
    [btop]=btop [udiskie]=udiskie [network-manager-applet]=nm-applet [network-manager-gnome]=nm-applet [blueman]=blueman-manager
    [pavucontrol]=pavucontrol [rofimoji]=rofimoji [awww]=awww [sddm]=sddm [brightnessctl]=brightnessctl [tesseract]=tesseract
    [tesseract-ocr]=tesseract [curl]=curl [ffmpeg]=ffmpeg [ffmpeg-free]=ffmpeg)
installed_pkg() {
    case $DISTRO in
        arch)   pacman -Qq "$1" &>/dev/null ;;
        fedora) rpm -q "$1" &>/dev/null ;;
        debian) dpkg -s "$1" &>/dev/null ;;
        *) return 1 ;;
    esac
}
have() { installed_pkg "$1" || { [[ -n ${CMD_OF[$1]:-} ]] && command -v "${CMD_OF[$1]}" >/dev/null 2>&1; }; }
has_pkg() {  # is this package available from the distro's repos?
    case $DISTRO in
        arch)   pacman -Si "$1" &>/dev/null ;;
        fedora) ((ATOMIC)) && return 0   # rpm-ostree can't be queried cheaply: pkg_install reports what failed
                dnf -q info "$1" &>/dev/null ;;
        debian) [[ -n $(apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p' | grep -v '(none)') ]] ;;
    esac
}
# Immutable Fedora: Bazzite ships its own (Terra) Xwayland, which conflicts with the one Hyprland's package asks for.
XWL_TRIED=0; XWL_PENDING=0; DEFERRED=()
fix_xwayland() {
    ((XWL_TRIED)) && return 1; XWL_TRIED=1
    local cur; cur=$(rpm -qa 2>/dev/null | grep -i 'xorg-x11-server-Xwayland' | grep -vi '^xorg-x11-server-Xwayland-[0-9]' | head -1)
    [[ -z $cur ]] && return 1
    cur=${cur%%-[0-9]*}
    echo "  This system ships its own Xwayland ($cur), which conflicts with the one Hyprland's package asks for."
    echo "  The swap is staged now and applied at the next reboot; Hyprland itself installs when you run this installer a second time."
    echo "  (Your current system stays bootable: if anything looks wrong, pick the previous entry in the boot menu or run: rpm-ostree rollback)"
    local ans=y
    if [[ -r /dev/tty ]]; then read -r -p "  Swap it for Fedora's Xwayland so Hyprland can install? (older version, fine for Hyprland) [Y/n] " ans </dev/tty || ans=y; fi
    [[ $ans =~ ^[Nn] ]] && return 1
    sudo rpm-ostree override remove "$cur" --install xorg-x11-server-Xwayland
}
# rpm-ostree runs one job at a time. If one is already running (maybe an earlier run of this installer), offer to cancel it.
rpmostree_wait() {
    rpm-ostree status 2>/dev/null | grep -qiE '^ *(State: busy|Transaction:)' || return 0
    local ans=y
    echo "  Another rpm-ostree job is already running (maybe an earlier run of this installer)."
    [[ -r /dev/tty ]] && { read -r -p "  Cancel it and continue? [Y/n] " ans </dev/tty || ans=y; }
    if [[ $ans =~ ^[Nn] ]]; then echo "  OK. Let it finish (or run: sudo rpm-ostree cancel), then run ./install.sh again."; exit 1; fi
    sudo rpm-ostree cancel || true
    sleep 2
}
# Is the Xwayland swap already staged (terra's still installed, but its removal is queued for the next boot)?
swap_pending() {
    rpm -qa 2>/dev/null | grep -qi '^terra-xorg-x11-server-Xwayland' || return 1
    rpm-ostree status 2>/dev/null | grep -qi 'terra-xorg-x11-server-Xwayland'
}
# Layer packages with rpm-ostree: drop the ones Fedora doesn't have, then fall back to one at a time for conflicts.
atomic_install() {
    local list=("$@") tmp rc nf p keep attempt
    tmp=$(mktemp)
    if swap_pending; then   # a previous run already staged the swap: hold Hyprland back right away instead of failing on it again
        XWL_PENDING=1; keep=()
        for p in "${list[@]}"; do
            case $p in hyprland|xdg-desktop-portal-hyprland) DEFERRED+=("$p") ;; *) keep+=("$p") ;; esac
        done
        list=("${keep[@]}")
        echo "  The Xwayland swap is already staged, so Hyprland itself waits for the reboot."
    fi
    for attempt in 1 2 3 4; do
        rpmostree_wait
        set +e; sudo rpm-ostree install --idempotent --allow-inactive "${list[@]}" 2>&1 | tee "$tmp"; rc=${PIPESTATUS[0]}; set -e
        ((rc == 0)) && { rm -f "$tmp"; return 0; }
        nf=$(sed -n 's/.*Packages not found: //p' "$tmp" | head -1)
        if [[ -z $nf ]]; then
            if grep -qi 'xwayland' "$tmp" && fix_xwayland; then
                # the swap only takes effect after a reboot, so Hyprland can't be layered yet: hold it back and do the rest now
                XWL_PENDING=1; keep=()
                for p in "${list[@]}"; do
                    case $p in hyprland|xdg-desktop-portal-hyprland) DEFERRED+=("$p") ;; *) keep+=("$p") ;; esac
                done
                list=("${keep[@]}"); ((${#list[@]})) || { rm -f "$tmp"; return 0; }
                continue
            fi
            break
        fi
        echo "  Not in your Fedora's repos, skipping: $nf"
        keep=()
        for p in "${list[@]}"; do
            if [[ " $nf " == *" $p "* ]]; then MISSING+=("$p"); else keep+=("$p"); fi
        done
        list=("${keep[@]}")
        ((${#list[@]})) || { rm -f "$tmp"; return 0; }
    done
    echo "  Some packages conflict with this system, installing them one at a time..."
    for p in "${list[@]}"; do
        rpmostree_wait
        if sudo rpm-ostree install --idempotent --allow-inactive "$p" 2>&1 | tee "$tmp"; [[ ${PIPESTATUS[0]} -eq 0 ]]; then continue; fi
        MISSING+=("$p")
    done
    rm -f "$tmp"
}

pkg_install() {
    case $DISTRO in
        arch)   sudo pacman -S --needed --noconfirm "$@" ;;
        fedora)
            if ((ATOMIC)); then atomic_install "$@"
            else
                sudo dnf install -y "$@"
            fi ;;
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
            if pick_copr; then
                o=${COPR%/*}; p=${COPR#*/}
                if ((ATOMIC)); then
                    say "Immutable Fedora (Bazzite/Silverblue/Kinoite) found: adding the $COPR Hyprland COPR and layering packages with rpm-ostree"
                    sudo curl -fsSL -o "/etc/yum.repos.d/$o-$p.repo" \
                        "https://copr.fedorainfracloud.org/coprs/$o/$p/repo/fedora-$FEDORA_VER/$o-$p-fedora-$FEDORA_VER.repo"
                else
                    say "Enabling the $COPR Hyprland COPR (Fedora's own Hyprland is too old for this config)"
                    sudo dnf install -y dnf-plugins-core
                    sudo dnf copr enable -y "$COPR"
                fi
            else
                say "No Hyprland COPR has packages for Fedora $FEDORA_VER yet"
                echo "  This config needs Hyprland 0.56 or newer, and Fedora's own Hyprland is older. I'll install everything else;"
                echo "  install a current Hyprland yourself (or move to a Fedora version that has a COPR), then run this again."
                keep=(); for p in "${PKGS[@]}"; do [[ $p == hyprland ]] || keep+=("$p"); done; PKGS=("${keep[@]}"); MISSING+=("hyprland(0.56+)")
            fi ;;
        debian) sudo apt-get update ;;
    esac
    say "Installing packages (anything your distro doesn't ship is listed at the end)"
    want=()
    for p in "${PKGS[@]}"; do
        if ((ATOMIC)) && [[ $p == sddm ]]; then continue; fi   # the image already has its own login screen
        if have "$p"; then SKIPPED+=("$p")
        elif has_pkg "$p"; then want+=("$p")
        else MISSING+=("$p"); fi
    done
    ((${#SKIPPED[@]})) && echo "  Already installed, skipping: ${SKIPPED[*]}"
    if ((${#want[@]})); then echo "  Installing: ${want[*]}"; pkg_install "${want[@]}"; else echo "  Nothing to install from the repos."; fi
    if [[ $DISTRO == arch ]]; then
        helper=$(command -v yay || command -v paru || true)
        if [[ -n $helper ]]; then
            say "Installing AUR packages with ${helper##*/}"
            aur_want=(); for p in "${AUR[@]}"; do have "$p" || aur_want+=("$p"); done
            ((${#aur_want[@]})) && { "$helper" -S --needed --noconfirm "${aur_want[@]}" || MISSING+=("${aur_want[@]}"); }
        else
            for p in "${AUR[@]}"; do have "$p" || MISSING+=("$p"); done
            echo "No yay/paru found: install the missing AUR packages yourself (${AUR[*]})"
        fi
    fi
    install_nerd_font
    [[ $DISTRO != arch ]] && install_starship
fi

# ---- SDDM: the login screen, set to start Hyprland ----------------------------------------
setup_sddm() {
    command -v sddm >/dev/null || return 0
    say "Setting up SDDM as your login screen"
    local current; current=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    [[ $DISTRO == debian ]] && echo /usr/bin/sddm | sudo tee /etc/X11/default-display-manager >/dev/null
    sudo systemctl enable -f sddm.service
    sudo mkdir -p /var/lib/sddm
    if [[ ! -e /var/lib/sddm/state.conf ]]; then   # preselect the Hyprland session the first time
        local sess=/usr/share/wayland-sessions/hyprland.desktop
        [[ -e $sess ]] && printf '[Last]\nSession=%s\n' "$sess" | sudo tee /var/lib/sddm/state.conf >/dev/null
    fi
    if [[ -n $current && $current != sddm.service && $current != . ]]; then
        echo "  Switched your login screen from ${current%.service} to SDDM. It takes effect at the next reboot."
    else
        echo "  SDDM will start at the next boot with Hyprland preselected."
    fi
}
if ((ATOMIC)); then
    echo "Immutable Fedora: leaving your login screen alone. Pick Hyprland from the session menu at login (after the reboot)."
elif [[ $DISTRO != unknown ]]; then
    setup_sddm
fi

# ---- NVIDIA ----------------------------------------------------------------------------
if ((HAS_NVIDIA)) && ((ATOMIC)); then
    say "NVIDIA GPU found"
    echo "  Bazzite/Fedora Atomic NVIDIA images already include the driver, so I'm not touching it."
elif ((HAS_NVIDIA)) && [[ $DISTRO != unknown ]]; then
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
if [[ $EDITION == laptop ]]; then
    say "Adding the laptop extras (battery module, brightness keys, low-battery warnings)"
    cp -a "$HERE"/editions/laptop/. "$CFG/"
    printf 'Brightness keys            Screen brightness (laptop)\n' >>"$CFG/hypr/keybinds.txt"
fi
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
    sudo install -m 755 "$HERE/editions/pc/rice-max-performance" /usr/local/bin/rice-max-performance
    sudo install -m 644 "$HERE/editions/pc/rice-max-performance.service" /etc/systemd/system/rice-max-performance.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now rice-max-performance.service
fi

say "Generating the default style (noir)"
"$CFG/rices/wardrobe.py" apply noir || true

# ---- report ------------------------------------------------------------------------------
say "Dependency check"
absent=()
if ((ATOMIC)); then
    echo "  Layered packages (Hyprland, Waybar, ...) are applied by rpm-ostree on the next boot, so they can't be checked yet."
fi
for c in Hyprland hyprctl waybar wofi dunst kitty hypridle hyprpaper wlogout starship awww cliphist \
         wl-copy grim slurp hyprpicker wf-recorder playerctl thunar sddm python3 ffmpeg curl notify-send; do
    command -v "$c" >/dev/null 2>&1 || [[ -x $HOME/.local/bin/$c ]] || absent+=("$c")
done
if ((${#absent[@]})) && ! ((ATOMIC)); then
    echo "  Not found on this system: ${absent[*]}"
    echo "  (awww sets the wallpaper: https://codeberg.org/LGFae/awww . Install anything missing from your distro or by hand.)"
fi
if ((${#MISSING[@]})); then echo "  Not available from your distro's repos: ${MISSING[*]}"; fi
if command -v Hyprland >/dev/null && ! printf '0.56\n%s\n' "$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)" | sort -VC; then
    echo "  WARNING: this config is written for Hyprland 0.56+ (the Lua config format). Your Hyprland looks older and may not load it."
fi

if ((XWL_PENDING)); then
cat <<MSG

Almost done. Reboot now, then run  ./install.sh  one more time to finish: ${DEFERRED[*]} could not be installed yet,
because the Xwayland swap above only takes effect after a reboot. After the second run, reboot again and pick the Hyprland session.
Everything else (configs, wallpapers, the other packages) is already in place.
MSG
exit 0
fi
cat <<MSG

Done. Reboot, then pick the Hyprland session on the login screen.
  Super+Shift+R   switch rice style (Wardrobe)       Super+W   wallpapers
  Super+Shift+D   displays                           Super+F1  welcome / how to use it
  Super+/         cheat sheet of every shortcut
Your old configs, if any, are in: $BACKUP
Weather: set WEATHER_LOCATION="City,State" in your environment to pin it (default: guessed from your IP).
MSG
if [[ $EDITION == pc ]] && ((MAXPERF)); then
    echo "Max performance is ON (fans 100%, loud on purpose). Turn it off any time:  sudo systemctl disable --now rice-max-performance"
fi
