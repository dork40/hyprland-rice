#!/usr/bin/env bash
# test.sh <distro> <port>: fresh VM from the clean base image -> push this checkout -> run the new-user install -> report.
# KEEP=1 leaves the VM running. Bazzite (immutable) does install, reboot, install again, like a real user.
W=${WIRE_VMTEST:-$HOME/Projects/wire-vmtest}; HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
d=$1 p=$2
S=(ssh -q -i "$W/id_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p "$p" rice@127.0.0.1)
stopvm() { local pid; pid=$(pgrep -f "^qemu-system-x86_64 -name rice-$d ") && kill $pid 2>/dev/null; sleep 2; }
waitssh() { for _ in $(seq 1 120); do "${S[@]}" true 2>/dev/null && return 0; sleep 5; done; echo "[$d] no ssh"; return 1; }
stopvm
bash "$HERE/vm.sh" "$d" "$p" > "$W/logs/$d-qemu.log" 2>&1 &
sleep 3; waitssh || exit 1
"${S[@]}" 'cloud-init status --wait >/dev/null 2>&1; true'
tar -czf "$W/rice-$d.tgz" -C "$REPO" --exclude=.git --exclude=tests .
scp -q -i "$W/id_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$p" "$HERE/intest.sh" rice@127.0.0.1:
scp -q -i "$W/id_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$p" "$W/rice-$d.tgz" rice@127.0.0.1:rice.tgz
if [[ $d == bazzite* ]]; then
    "${S[@]}" 'PHASE=first bash intest.sh' > "$W/logs/$d-install-1.log" 2>&1
    grep '### RESULT' "$W/logs/$d-install-1.log"
    "${S[@]}" 'sudo systemctl reboot' ; sleep 20; waitssh || exit 1
    "${S[@]}" 'rpm-ostree status | head -12' >> "$W/logs/$d-install-1.log" 2>&1
fi
"${S[@]}" 'bash intest.sh' > "$W/logs/$d-install.log" 2>&1
grep '### RESULT' "$W/logs/$d-install.log"
echo "[$d] log: $W/logs/$d-install.log"
[[ ${KEEP:-} ]] || stopvm
