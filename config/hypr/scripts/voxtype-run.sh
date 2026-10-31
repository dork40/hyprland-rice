#!/bin/sh
# Runs the voxtype daemon from the Hyprland session (which has the 'input' group it needs to read the keyboard),
# restarting it if it exits. To apply config changes: pkill -f '^voxtype -q daemon'
while :; do
    voxtype -q daemon
    sleep 1
done
