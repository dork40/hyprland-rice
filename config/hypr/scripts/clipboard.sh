#!/usr/bin/env bash
# Pick an entry from clipboard history with wofi and copy it
cliphist list | wofi --dmenu --prompt "Clipboard" | cliphist decode | wl-copy
