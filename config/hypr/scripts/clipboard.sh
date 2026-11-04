#!/usr/bin/env bash
# Clipboard history in wofi, with thumbnails for copied images. Pick an entry to copy it again.
menu=$(cliphist list | head -80 | python3 -I ~/.config/hypr/scripts/clipboard-menu.py ~/.cache/cliphist-thumbs)
pick=$(printf '%s\n' "$menu" | wofi --dmenu --prompt "Clipboard" --allow-images --define image_size=72) || exit 0
id=$(grep -oE '[0-9]+' <<<"$pick" | head -1)
[ -n "$id" ] && cliphist decode "$id" | wl-copy
