#!/usr/bin/env bash
# Toggle dunst do-not-disturb and refresh the waybar indicator
dunstctl set-paused toggle
pkill -RTMIN+8 waybar
