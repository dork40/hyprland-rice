#!/usr/bin/env bash
# vmhypr.sh <port> <cmd...>: run a command inside the test VM's running Hyprland session (as user rice)
p=$1; shift
ssh -q -i "${WIRE_VMTEST:-$HOME/Projects/wire-vmtest}/id_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$p" rice@127.0.0.1 \
  'export XDG_RUNTIME_DIR=/run/user/$(id -u); export WAYLAND_DISPLAY=$(cd $XDG_RUNTIME_DIR && ls wayland-? | head -1)
   export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); '"$*"
