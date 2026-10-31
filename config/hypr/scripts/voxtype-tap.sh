#!/bin/sh
# Tap-to-talk from the Waybar mic: start (stops itself after silence), or stop early if already recording.
if [ "$(voxtype status)" = recording ]; then
    voxtype record stop
else
    voxtype record start && exec "$HOME/.config/voxtype/silence-stop.py"
fi
