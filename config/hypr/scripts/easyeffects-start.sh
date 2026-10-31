#!/usr/bin/env bash
# Start EasyEffects in the background: Laptop preset for the speakers, Mic preset (noise suppression) for the mic
easyeffects --service-mode &
for i in $(seq 1 20); do
    sleep 0.5
    easyeffects -l Laptop >/dev/null 2>&1 && break
done
easyeffects -l Mic >/dev/null 2>&1
easyeffects -b 2 >/dev/null 2>&1   # make sure effects are on (not bypassed)
