#!/usr/bin/env bash
# Waybar indicator for dunst do-not-disturb
if [ "$(dunstctl is-paused 2>/dev/null)" = "true" ]; then
  echo '{"text":"󰂛","class":"off","tooltip":"Notifications off"}'
else
  echo '{"text":"󰂚","class":"on","tooltip":"Notifications on"}'
fi
