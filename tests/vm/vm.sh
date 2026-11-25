#!/usr/bin/env bash
# vm.sh <distro> <ssh-port>: boot a throwaway copy of base/<distro>.qcow2 (the base image is never changed), headless.
# SSH on 127.0.0.1:<port>, VNC on 127.0.0.1:<port-2200+5900>, QMP socket run/<distro>.qmp (screenshots, keys)
set -euo pipefail
W=${WIRE_VMTEST:-$HOME/Projects/wire-vmtest}
d=$1 port=$2
cd "$W/run"
if [[ -z ${REUSE:-} || ! -f $d.qcow2 ]]; then   # REUSE=1 boots the existing disk again (after a test)
rm -f "$d.qcow2" "$d-seed.iso"
bs=$(qemu-img info --output=json "$W/base/$d.qcow2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')
qemu-img create -q -f qcow2 -b "$W/base/$d.qcow2" -F qcow2 "$d.qcow2" $((bs > 32212254720 ? bs : 32212254720))
cat > "$d-user-data" <<EOF
#cloud-config
users:
  - name: rice
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: rice
    ssh_authorized_keys:
      - $(cat "$W/id_vm.pub")
ssh_pwauth: false
growpart: {mode: auto, devices: ['/']}
resize_rootfs: true
EOF
printf 'instance-id: %s\nlocal-hostname: rice-%s\n' "$d" "$d" > "$d-meta"
cloud-localds "$d-seed.iso" "$d-user-data" "$d-meta"
fi
exec qemu-system-x86_64 -name "rice-$d" -enable-kvm -cpu host -smp 4 -m "${MEM:-4096}" \
  -drive file="$d.qcow2",if=virtio -drive file="$d-seed.iso",if=virtio,format=raw \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:$port-:22 -device virtio-net-pci,netdev=n0 \
  -device VGA,xres=${XRES:-1920},yres=${YRES:-1080},edid=on,vgamem_mb=64 -display none -vnc 127.0.0.1:$((port - 2200)) \
  -qmp unix:"$W/run/$d.qmp",server,nowait -serial file:"$W/logs/$d-serial.log"
