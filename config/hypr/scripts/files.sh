#!/usr/bin/env bash
# File search in wofi: type part of a name (several words allowed), pick a result to open it.
q=$(wofi --dmenu --prompt "Find files" --lines 0 </dev/null) || exit 0
[ -z "$q" ] && exit 0
# shellcheck disable=SC2086
res=$(plocate -i -A -l 5000 $q 2>/dev/null | grep "^$HOME/" | grep -v "/\." | head -80 | sed "s|^$HOME|~|")
[ -z "$res" ] && { notify-send -t 2500 "Find files" "Nothing found for: $q"; exit 0; }
pick=$(printf '%s\n' "$res" | wofi --dmenu --prompt "$q" --insensitive) || exit 0
xdg-open "${pick/#\~/$HOME}" >/dev/null 2>&1 &
