#!/usr/bin/env bash
# Keyboard backlight for waybar. Click cycles brightness, scroll steps it.
#   (no arg)  print waybar JSON     next|prev  change level
case "$1" in next|prev) asusctl leds "$1" >/dev/null; pkill -RTMIN+13 waybar; exit ;; esac
lvl=$(asusctl leds get 2>/dev/null | grep -oiE 'off|low|med|high' | head -1 | tr A-Z a-z)
case "$lvl" in
  off) icon="󰌶"; cls=off ;; low) icon="󰛨"; cls=low ;; med) icon="󰛨"; cls=med ;; high) icon="󰛨"; cls=high ;;
  *) icon="󰌌"; lvl=unknown; cls=off ;;
esac
echo "{\"text\":\"$icon\",\"class\":\"$cls\",\"tooltip\":\"Keyboard light: $lvl\\nClick: next level  ·  Scroll: up/down\"}"
