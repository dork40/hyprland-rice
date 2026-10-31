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

# Ask for the password once up front and keep it alive in the background (long installs never stall on a prompt)
if [[ $DISTRO != unknown ]] && command -v sudo >/dev/null; then
    sudo -v && { while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 40; done >/dev/null 2>&1 & }
fi

# Immutable Fedora (Bazzite, Silverblue, Kinoite, Aurora): dnf is blocked, packages are layered with rpm-ostree
ATOMIC=0
[[ $DISTRO == fedora && ( -e /run/ostree-booted || -n ${RICE_ATOMIC:-} ) ]] && ATOMIC=1

# ---- package lists: only what the rice itself uses --------------------------------
case $DISTRO in
arch)
    PKGS=(hyprland waybar wofi dunst kitty swayosd hypridle hyprpaper wlogout starship ttf-jetbrains-mono-nerd
          python python-gobject gtk4 gtk4-layer-shell ffmpeg curl libnotify xdg-desktop-portal-hyprland thunar sddm
          cliphist wl-clipboard grim slurp hyprpicker wf-recorder playerctl tesseract tesseract-data-eng btop udiskie
          network-manager-applet blueman polkit-kde-agent pavucontrol papirus-icon-theme breeze awww rofimoji)
    AUR=()   # anything missing from the repos (wlogout, for example) is tried in the AUR automatically
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
        arch:amd|arch:hybrid-amd)       PKGS+=(mesa vulkan-radeon) ;;
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
# One query per distro for everything we need to know (was one slow query per package)
declare -A INST AVAIL
load_state() {
    local n names; names=$(printf '%s\n' "${PKGS[@]}" "${AUR[@]}")
    # (only the ~45 names we care about are kept: the package lists have tens of thousands of entries)
    case $DISTRO in
        arch)
            while read -r n; do INST[$n]=1; done < <(pacman -Qq 2>/dev/null | grep -Fx -f <(echo "$names"))
            while read -r n; do AVAIL[$n]=1; done < <(pacman -Slq 2>/dev/null | grep -Fx -f <(echo "$names")) ;;
        fedora)
            while read -r n; do INST[$n]=1; done < <(rpm -qa --qf '%{NAME}\n' 2>/dev/null | grep -Fx -f <(echo "$names"))
            if ((! ATOMIC)); then   # rpm-ostree can't be queried: layering reports what is missing
                while read -r n; do AVAIL[$n]=1; done < <(dnf -q repoquery --available --qf '%{name}\n' "${PKGS[@]}" 2>/dev/null)
            fi ;;
        debian)
            while read -r n; do INST[$n]=1; done < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | grep -Fx -f <(echo "$names"))
            while read -r n; do AVAIL[$n]=1; done < <(apt-cache policy "${PKGS[@]}" 2>/dev/null | awk '/^[^ ]/{p=$1; sub(":$","",p)} /Candidate:/{if($2!="(none)")print p}') ;;
    esac
}
installed_pkg() { [[ -n ${INST[$1]:-} ]]; }
have() { installed_pkg "$1" || { [[ -n ${CMD_OF[$1]:-} ]] && command -v "${CMD_OF[$1]}" >/dev/null 2>&1; }; }
has_pkg() { ((ATOMIC)) && return 0; [[ -n ${AVAIL[$1]:-} ]]; }   # atomic: pkg_install reports what failed
# Immutable Fedora: Bazzite ships its own (Terra) Xwayland, which conflicts with the one Hyprland's package asks for.
XWL_TRIED=0; XWL_PENDING=0; XWL_MODE=""; DEFERRED=(); HYPR_ERR=""
# Bazzite ships Terra's Xwayland, which blocks Hyprland's package. Half-finished earlier attempts leave "inactive" state behind that
# keeps the solver failing, so: clear this machine's layered packages/overrides (keeping any that are not ours), then do the swap and
# ALL the installs in one transaction, which needs a single reboot.
clean_slate_swap() {
    local cur=$1 tmp attempt p seen=" " args=() other=()
    tmp=$(mktemp)
    while read -r p; do [[ -n $p ]] && other+=("$p"); done < <(rpm-ostree status --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); b=[x for x in d['deployments'] if x.get('booted')]
    print('\n'.join(b[0].get('requested-packages',[]) if b else []))
except Exception: pass" 2>/dev/null)
    for attempt in 1 2 3 4; do
        args=(); seen=" "
        for p in "${PKGS[@]}" "${other[@]}" xorg-x11-server-Xwayland; do
            [[ $p == sddm || $seen == *" $p "* ]] && continue
            printf '%s\n' "${MISSING[@]:-}" | grep -qx "$p" && continue
            seen+="$p "; args+=(--install "$p")
        done
        rpmostree_wait
        if ((attempt == 1)); then echo "  Clearing the earlier half-finished package changes..."; sudo rpm-ostree reset || true; fi
        set +e; sudo rpm-ostree override remove "$cur" "${args[@]}" 2>&1 | tee "$tmp"; local rc=${PIPESTATUS[0]}; set -e
        ((rc == 0)) && { rm -f "$tmp"; return 0; }
        local nf; nf=$(sed -n 's/.*Packages not found: //p' "$tmp" | head -1)
        [[ -z $nf ]] && break
        echo "  Not in your Fedora's repos, skipping: $nf"
        for p in $nf; do MISSING+=("$p"); done
    done
    HYPR_ERR=$(grep -iE 'error|problem|conflict|requires|not found|nothing provides' "$tmp" | head -6)
    # leave the machine as it was before: put the packages back, without Hyprland
    echo "  That didn't work. Restoring the packages without Hyprland..."
    rpmostree_wait
    local back=(); for p in "${PKGS[@]}" "${other[@]}"; do [[ $p == hyprland || $p == sddm ]] && continue; back+=("$p"); done
    sudo rpm-ostree install --idempotent --allow-inactive "${back[@]}" >/dev/null 2>&1 || true
    rm -f "$tmp"; return 1
}
fix_xwayland() {
    ((XWL_TRIED)) && return 1; XWL_TRIED=1
    local cur; cur=$(rpm -qa 2>/dev/null | grep -i 'xorg-x11-server-Xwayland' | grep -vi '^xorg-x11-server-Xwayland-[0-9]' | head -1)
    [[ -z $cur ]] && return 1
    cur=${cur%%-[0-9]*}
    if [[ $cur == terra-* ]]; then   # Bazzite: tried repeatedly, rpm-ostree cannot swap this one (see offer_wayblue at the end)
        XWL_MODE=blocked
        HYPR_ERR="Bazzite's own Xwayland ($cur) conflicts with the Xwayland that Hyprland's package needs, and rpm-ostree cannot swap it."
        return 1
    fi
    echo "  This system ships its own Xwayland ($cur), which blocks Hyprland's package."
    echo "  I will swap it for Fedora's Xwayland (older version, fine for Hyprland) and install everything in one step."
    echo "  It takes effect at the next reboot. Your current system stays bootable: if anything looks wrong, pick the previous"
    echo "  entry in the boot menu or run: rpm-ostree rollback"
    local ans=y
    if [[ -r /dev/tty ]]; then read -r -p "  Continue? [Y/n] " ans </dev/tty || ans=y; fi
    [[ $ans =~ ^[Nn] ]] && return 1
    if clean_slate_swap "$cur"; then XWL_MODE=combined; return 0; fi
    return 1
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
    rpm-ostree status -v 2>/dev/null | grep -qi 'terra-xorg-x11-server-Xwayland'
}
# Layer packages with rpm-ostree: drop the ones Fedora doesn't have, then fall back to one at a time for conflicts.
atomic_install() {
    local list=("$@") tmp rc nf p keep attempt
    tmp=$(mktemp)
    for attempt in 1 2 3 4; do
        rpmostree_wait
        set +e; sudo rpm-ostree install --idempotent --allow-inactive "${list[@]}" 2>&1 | tee "$tmp"; rc=${PIPESTATUS[0]}; set -e
        ((rc == 0)) && { rm -f "$tmp"; return 0; }
        nf=$(sed -n 's/.*Packages not found: //p' "$tmp" | head -1)
        if [[ -z $nf ]]; then
            if { grep -qi 'xwayland' "$tmp" || { printf '%s\n' "${list[@]}" | grep -qx hyprland && rpm -qa 2>/dev/null | grep -qi '^terra-xorg-x11-server-Xwayland'; }; } && fix_xwayland; then
                XWL_PENDING=1; rm -f "$tmp"; return 0   # everything, Hyprland included, is queued together for the next boot
            fi
            if [[ $XWL_MODE == blocked ]]; then
                keep=(); for p in "${list[@]}"; do [[ $p == hyprland || $p == xdg-desktop-portal-hyprland ]] && continue; keep+=("$p"); done
                MISSING+=(hyprland); list=("${keep[@]}"); ((${#list[@]})) || { rm -f "$tmp"; return 0; }
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
    echo "  Some packages conflict with this system, retrying in small groups..."
    local i g size=6
    for ((i = 0; i < ${#list[@]}; i += size)); do
        g=("${list[@]:i:size}")
        rpmostree_wait
        if sudo rpm-ostree install --idempotent --allow-inactive "${g[@]}" 2>&1 | tee "$tmp"; [[ ${PIPESTATUS[0]} -eq 0 ]]; then continue; fi
        for p in "${g[@]}"; do   # only the failing group is split up
            rpmostree_wait
            if sudo rpm-ostree install --idempotent --allow-inactive "$p" 2>&1 | tee "$tmp"; [[ ${PIPESTATUS[0]} -eq 0 ]]; then continue; fi
            [[ $p == hyprland ]] && HYPR_ERR=$(grep -iE 'error|problem|conflict|requires|not found|nothing provides' "$tmp" | head -6)
            MISSING+=("$p")
        done
    done
    rm -f "$tmp"
}

pkg_install() {
    case $DISTRO in
        arch)   sudo pacman -S --needed --noconfirm "$@" ;;
        fedora)
            if ((ATOMIC)); then atomic_install "$@"
            else
                sudo dnf install -y --setopt=max_parallel_downloads=10 "$@"
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
                    dnf copr --help >/dev/null 2>&1 || sudo dnf install -y dnf-plugins-core
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
    if [[ $DISTRO != arch ]]; then   # download the font and the prompt in the background while packages install
        PREFETCH_LOG=$(mktemp)
        { install_nerd_font; install_starship; } >"$PREFETCH_LOG" 2>&1 &
        PREFETCH_PID=$!
    fi
    load_state
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
        aur_try=(); for p in "${MISSING[@]}" "${AUR[@]}"; do have "$p" || aur_try+=("$p"); done
        MISSING=()
        if ((${#aur_try[@]})); then
            helper=$(command -v yay || command -v paru || true)
            if [[ -n $helper ]]; then
                say "Installing from the AUR with ${helper##*/}: ${aur_try[*]}"
                if ! "$helper" -S --needed --noconfirm "${aur_try[@]}"; then
                    for p in "${aur_try[@]}"; do "$helper" -S --needed --noconfirm "$p" || MISSING+=("$p"); done
                fi
            else
                MISSING+=("${aur_try[@]}"); echo "No yay or paru found: install these from the AUR yourself: ${aur_try[*]}"
            fi
        fi
        install_nerd_font
    fi
    if [[ -n ${PREFETCH_PID:-} ]]; then
        wait "$PREFETCH_PID" || echo "  (the font/prompt download had a problem)"
        sed -n 's/^.*==> //p' "$PREFETCH_LOG" | sed 's/^/  /'
    fi
fi

# ---- SDDM: the login screen, set to start Hyprland ----------------------------------------
# The login screen remembers the last session; make that Hyprland (also on immutable Fedora/Bazzite, where SDDM already exists)
preselect_hyprland_session() {
    if [[ -e /usr/lib/systemd/system/plasmalogin.service || -e /etc/systemd/system/plasmalogin.service ]]; then
        echo "  Your login screen is Plasma Login Manager: choose Hyprland from its session menu (it is not preselected)."
        return 0
    fi
    command -v sddm >/dev/null || [[ -d /var/lib/sddm ]] || return 0
    sudo mkdir -p /var/lib/sddm
    printf '[Last]\nSession=/usr/share/wayland-sessions/hyprland.desktop\nUser=%s\n' "${SUDO_USER:-$USER}" | sudo tee /var/lib/sddm/state.conf >/dev/null
}
setup_sddm() {
    command -v sddm >/dev/null || return 0
    say "Setting up SDDM as your login screen"
    local current; current=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    [[ $DISTRO == debian ]] && echo /usr/bin/sddm | sudo tee /etc/X11/default-display-manager >/dev/null
    sudo systemctl enable -f sddm.service
    sudo mkdir -p /var/lib/sddm
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
[[ $DISTRO != unknown ]] && preselect_hyprland_session

# ---- NVIDIA ----------------------------------------------------------------------------
if ((HAS_NVIDIA)) && ((ATOMIC)) && rpm-ostree status 2>/dev/null | grep -qi wayblue; then
    say "NVIDIA GPU found (Wayblue image): setting the kernel options it needs"
    sudo rpm-ostree kargs --append-if-missing=rd.driver.blacklist=nouveau --append-if-missing=modprobe.blacklist=nouveau \
        --append-if-missing=nvidia-drm.modeset=1 --append-if-missing=nvidia-drm.fbdev=1 || true
    echo "  Reboot once after this installer so the options apply."
elif ((HAS_NVIDIA)) && ((ATOMIC)); then
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

# Fedora Atomic (Bazzite): Hyprland's package cannot be layered next to Terra's Xwayland. The reliable route is an image that ships Hyprland.
offer_wayblue() {
    ((ATOMIC)) || return 0
    rpm-ostree status 2>/dev/null | grep -qi wayblue && return 0
    local img=hyprland cur
    case $GPU in nvidia|hybrid-amd|hybrid-intel) img=hyprland-nvidia-open ;; esac
    cur=$(rpm-ostree status --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); b=[x for x in d['deployments'] if x.get('booted')]; print(b[0].get('container-image-reference','') if b else '')
except Exception: pass" 2>/dev/null)
    echo
    echo "  Hyprland can't be added on top of this system image: Bazzite's own Xwayland blocks Hyprland's package, and no repo has a fix."
    echo "  What does work on Fedora Atomic is Wayblue's Hyprland image ($img): Hyprland, Waybar and the NVIDIA setup come preinstalled,"
    echo "  and this installer then adds the rice on top. You lose Bazzite's extras (game mode, Bazzite tools)."
    echo "  You can go back at any time with:  sudo rpm-ostree rebase ${cur:-ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable}"
    [[ -r /dev/tty ]] || return 0
    local ans=n; read -r -p "  Switch to the Wayblue image now? (two reboots, then run ./install.sh again) [y/N] " ans </dev/tty || return 0
    [[ $ans =~ ^[Yy] ]] || { echo "  OK, nothing changed."; return 0; }
    rpmostree_wait
    sudo rpm-ostree reset || true
    sudo rpm-ostree rebase "ostree-unverified-registry:ghcr.io/wayblueorg/$img:latest"
    cat <<MSG

  Step 1 of 2 is done. Now:
    systemctl reboot
  After that reboot (it can take a while the first time), run these two commands, then reboot again:
    sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/wayblueorg/$img:latest
    systemctl reboot
  Then run  ./install.sh  one more time: it detects Wayblue and finishes the setup (including the NVIDIA settings).
MSG
}

# At the end: say clearly whether Hyprland is really there (and if not, why)
verify_hyprland() {
    say "Checking that Hyprland is installed"
    if [[ -e /usr/share/wayland-sessions/hyprland.desktop ]] && command -v Hyprland >/dev/null; then
        echo "  OK: Hyprland is installed and its login session exists."; return 0
    fi
    if [[ $XWL_MODE == combined ]]; then
        echo "  Hyprland and the Xwayland swap are queued together. Reboot to get both; Hyprland will then be in the login screen's session menu."; return 0
    fi
    if ((ATOMIC)) && rpm-ostree status 2>/dev/null | grep -qE '(^|[[:space:]])hyprland($|[[:space:]])'; then
        echo "  Hyprland is queued in the next boot image. Reboot to get it; it will then appear in the login screen's session menu."; return 0
    fi
    echo "  Hyprland is NOT installed yet, so the login screen can't offer it."
    if printf '%s\n' "${MISSING[@]:-}" | grep -qi 'hyprland(0.56+)'; then echo "  Reason: no Hyprland COPR has packages for your Fedora version (see above)."
    elif printf '%s\n' "${MISSING[@]:-}" | grep -qi hyprland; then
        echo "  The package manager refused to install it. What it said:"
        if [[ -n $HYPR_ERR ]]; then sed 's/^/    /' <<<"$HYPR_ERR"; else echo "    (see the red error lines above)"; fi
        echo "  Run ./diagnose.sh and send me its output together with a photo of the lines above."
        offer_wayblue
    elif ((XWL_PENDING)); then echo "  Reason: it waits for the Xwayland swap. Reboot, then run ./install.sh again."
    else echo "  Run ./diagnose.sh and send me what it prints."; fi
}

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

verify_hyprland
if ((XWL_PENDING)) && [[ $XWL_MODE == combined ]]; then
cat <<MSG

Almost done. Reboot now: the Xwayland swap and Hyprland are installed together and both switch on at the next boot.
At the login screen choose the Hyprland session (click the session label, usually bottom-left, and pick Hyprland).
No session menu? Press Ctrl+Alt+F3, log in, and type: Hyprland
MSG
exit 0
fi
if ((XWL_PENDING)); then
cat <<MSG

Almost done. Reboot now, then run  ./install.sh  one more time to finish: ${DEFERRED[*]} could not be installed yet,
because the Xwayland swap above only takes effect after a reboot. After the second run, reboot again.
At the login screen Hyprland is preselected. If it still says "Plasma (Wayland)", click that label (usually bottom-left)
and choose Hyprland. No session menu? Press Ctrl+Alt+F3, log in, and type: Hyprland
Everything else (configs, wallpapers, the other packages) is already in place.
MSG
exit 0
fi
cat <<MSG

Done. Reboot, then log in.
At the login screen Hyprland is preselected. If it still says "Plasma (Wayland)", click that label (usually bottom-left)
and choose Hyprland. No session menu? Press Ctrl+Alt+F3, log in, and type: Hyprland
  Super+Shift+R   switch rice style (Wardrobe)       Super+W   wallpapers
  Super+Shift+D   displays                           Super+F1  welcome / how to use it
  Super+/         cheat sheet of every shortcut
Your old configs, if any, are in: $BACKUP
Weather: set WEATHER_LOCATION="City,State" in your environment to pin it (default: guessed from your IP).
MSG
if [[ $EDITION == pc ]] && ((MAXPERF)); then
    echo "Max performance is ON (fans 100%, loud on purpose). Turn it off any time:  sudo systemctl disable --now rice-max-performance"
fi
