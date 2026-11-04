#!/usr/bin/env bash
# Dunst runs this for each shown notification (env DUNST_URGENCY etc). Quiet for low urgency.
# per-rice switch (hypr/scripts/sounds.sh, quick-settings panel)
grep -qx "$(cat ~/.config/rices/current 2>/dev/null || echo noir)" ~/.config/rices/sounds-off 2>/dev/null && exit 0
case "$DUNST_URGENCY" in
  LOW) exit 0 ;;
  CRITICAL) f=dialog-warning ;;
  *) f=message ;;
esac
canberra-gtk-play -i "$f" 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/$f.oga
