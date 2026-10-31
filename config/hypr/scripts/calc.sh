#!/usr/bin/env bash
# Calculator in wofi: type a sum (12*7, 15% of 80, 5 km to mi) and press Enter.
# The answer shows on top; pick it to copy it, or type another sum.
lines=()
while :; do
    input=$(printf '%s\n' "${lines[@]}" | wofi --dmenu --prompt "Calculate" --lines 4) || exit 0
    if [[ $input == "= "* ]]; then
        printf '%s' "${input#= }" | wl-copy
        notify-send -t 2000 "Copied ${input#= }"
        exit
    fi
    [ -z "$input" ] && exit 0
    lines=("= $(qalc -t "$input" 2>&1 | tail -n1)" "$input")
done
