#!/usr/bin/env bash
# Per-rice notification sound switch. sounds.sh [status|toggle|on|off]  (acts on the current rice)
f=~/.config/rices/sounds-off
rice=$(cat ~/.config/rices/current 2>/dev/null || echo noir)
touch "$f"
off() { grep -qx "$rice" "$f"; }
act=${1:-status}
if [ "$act" = toggle ]; then if off; then act=on; else act=off; fi; fi
case "$act" in
  on)  sed -i "/^$rice\$/d" "$f"; canberra-gtk-play -i message >/dev/null 2>&1 & ;;
  off) off || echo "$rice" >> "$f" ;;
esac
if off; then echo off; else echo on; fi
