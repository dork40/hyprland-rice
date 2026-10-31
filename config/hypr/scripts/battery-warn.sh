#!/usr/bin/env bash
# Warn once at 15% and again at 5% while the battery is draining
bat=/sys/class/power_supply/BAT0
warned=100
while sleep 60; do
    cap=$(<"$bat/capacity"); status=$(<"$bat/status")
    if [ "$status" != Discharging ]; then warned=100; continue; fi
    if (( cap <= 5 && warned > 5 )); then
        notify-send -u critical -i battery-empty "Battery at $cap%" "Plug in now, the laptop will shut down soon"; warned=5
    elif (( cap <= 15 && warned > 15 )); then
        notify-send -u critical -i battery-caution "Battery low: $cap%" "Plug in the charger soon"; warned=15
    fi
done
