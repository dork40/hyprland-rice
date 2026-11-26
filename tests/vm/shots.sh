#!/usr/bin/env bash
# shots.sh <port> [looks...]: README screenshots of each look on a test VM that is logged into Hyprland.
# Opens fastfetch + btop the same way for every look, so they compare fairly. Output: docs/screenshots/<look>.jpg
set -uo pipefail
port=$1; shift
looks=${*:-noir liquid mono aurora}
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
W=${WIRE_VMTEST:-$HOME/Projects/wire-vmtest}
vm() { bash "$HERE/vmhypr.sh" "$port" "$@"; }
name=$(pgrep -af "qemu-system-x86_64 -name rice-" | grep -- "hostfwd=tcp:127.0.0.1:$port-" | sed -n 's/.*-name rice-\([^ ]*\).*/\1/p' | head -1)
[[ -n $name ]] || { echo "no VM on port $port"; exit 1; }

for look in $looks; do
    echo "== $look"
    vm "pkill -x kitty; pkill -f '^python3 .*rices/picker.py'; pkill -f '^python3 .*rices/welcome.py'; mkdir -p ~/.local/state; touch ~/.local/state/rice-welcome-done; true"
    vm "python3 ~/.config/rices/wardrobe.py apply $look >/dev/null 2>&1"
    sleep 6
    vm "cd ~; setsid -f kitty --hold fastfetch >/dev/null 2>&1 </dev/null"
    sleep 3
    vm "setsid -f kitty btop >/dev/null 2>&1 </dev/null"
    sleep 9                               # let btop draw its graphs and the blur settle
    python3 "$HERE/shot.py" "$name" "$W/shots/look-$look.png" >/dev/null &&
        ffmpeg -loglevel error -y -i "$W/shots/look-$look.png" -q:v 3 "$REPO/docs/screenshots/$look.jpg" &&
        echo "   docs/screenshots/$look.jpg"
done

echo "== wardrobe"
vm "pkill -x kitty; true"
vm "python3 ~/.config/rices/wardrobe.py apply noir >/dev/null 2>&1"
sleep 6
vm "LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so setsid -f python3 ~/.config/rices/picker.py >/dev/null 2>&1 </dev/null"
sleep 4
python3 "$HERE/shot.py" "$name" "$W/shots/look-wardrobe.png" >/dev/null &&
    ffmpeg -loglevel error -y -i "$W/shots/look-wardrobe.png" -q:v 3 "$REPO/docs/screenshots/wardrobe.jpg" &&
    echo "   docs/screenshots/wardrobe.jpg"
vm "pkill -f '^python3 .*rices/picker.py'; true"
