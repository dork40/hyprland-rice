#!/usr/bin/env bash
# Waybar Tailscale button. (no arg) prints status, "toggle" connects/disconnects.
state() { tailscale status --json 2>/dev/null | python3 -c 'import json,sys
d=json.load(sys.stdin); peers=d.get("Peer") or {}
print(d["BackendState"], sum(1 for p in peers.values() if p.get("Online")), d["Self"]["TailscaleIPs"][0] if d.get("Self") and d["Self"].get("TailscaleIPs") else "")'; }

if [ "$1" = toggle ]; then
    read -r st _ <<<"$(state)"
    if [ "$st" = Running ]; then cmd=down; msg="Tailscale off"; else cmd=up; msg="Tailscale on"; fi
    if err=$(tailscale $cmd 2>&1); then
        notify-send -t 2000 "$msg"
    else
        notify-send -t 6000 "Tailscale: permission needed" "Run once in a terminal:  sudo tailscale set --operator=\$USER"
    fi
    pkill -RTMIN+13 waybar
    exit
fi

read -r st online ip <<<"$(state)"
if [ "$st" = Running ]; then
    echo "{\"text\":\"󰖂\",\"class\":\"on\",\"tooltip\":\"Tailscale on · $ip\\n$online other device(s) online\\nClick to turn off\"}"
else
    echo "{\"text\":\"󰖂\",\"class\":\"off\",\"tooltip\":\"Tailscale off\\nClick to turn on\"}"
fi
