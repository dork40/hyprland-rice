#!/usr/bin/env bash
# Dropdown terminal: open it the first time, then show/hide it
if hyprctl clients -j | grep -q '"class": "dropdown"'; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")' >/dev/null
else
    setsid -f kitty --class dropdown >/dev/null 2>&1
fi
