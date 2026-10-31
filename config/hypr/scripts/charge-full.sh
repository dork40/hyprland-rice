#!/usr/bin/env bash
# Charge to 100% one time (for travel days); the 90% limit comes back after that charge
if asusctl battery oneshot >/dev/null 2>&1; then
    notify-send -t 4000 -i battery-full-charging "Charging to 100% once" "Your 90% limit comes back after this charge"
else
    notify-send -t 4000 "Couldn't start a full charge" "Is the charger plugged in?"
fi
