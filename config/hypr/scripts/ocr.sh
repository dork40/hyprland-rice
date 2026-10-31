#!/usr/bin/env bash
# Drag a box over any text on screen; the text is copied to the clipboard
area=$(slurp) || exit 0
text=$(grim -g "$area" -s 1.25 - | tesseract - - -l eng 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/^$/N;/^\n$/D')
if [ -n "${text//[[:space:]]/}" ]; then
    printf '%s' "$text" | wl-copy
    notify-send -t 3000 "Text copied" "$(printf '%s' "$text" | head -c 120)"
else
    notify-send -t 3000 "No text found" "Try a bigger box around the text"
fi
