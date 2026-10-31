#!/usr/bin/env bash
# Flip the battery charge limit between 90% (everyday) and 100% (travel).
cur=$(asusctl battery info 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ "${cur:-100}" -ge 100 ]; then new=90; else new=100; fi
if asusctl battery limit $new >/dev/null 2>&1; then
    notify-send -t 2500 "Charge limit $new%" "$([ $new = 90 ] && echo 'Easier on the battery' || echo 'Charges fully')"
else
    notify-send -t 3000 "Couldn't change the charge limit"
fi
