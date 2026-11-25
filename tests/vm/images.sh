#!/usr/bin/env bash
# images.sh: download the clean cloud images (and build the Bazzite one) into $WIRE_VMTEST/base. Skips what is there.
set -euo pipefail
W=${WIRE_VMTEST:-$HOME/Projects/wire-vmtest}; HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$W"/{base,run,logs,shots}; cd "$W"
[[ -f id_vm ]] || ssh-keygen -t ed25519 -N '' -f id_vm -q -C rice-vmtest
dl() { [[ -f base/$2 ]] && return 0; echo "downloading $2"; wget -q -O "base/$2.part" "$1" && mv "base/$2.part" "base/$2" && echo "  done $2"; }
F=$(curl -fsSL https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Cloud/x86_64/images/ | grep -oE 'Fedora-Cloud-Base-Generic-45[^"]*x86_64\.qcow2' | head -1)
dl https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2 arch.qcow2 &
dl https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img ubuntu24.qcow2 &
dl https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img ubuntu26.qcow2 &
dl "https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Cloud/x86_64/images/$F" fedora.qcow2 &
wait
if [[ ! -f base/bazzite.qcow2 && -z ${NO_BAZZITE:-} ]]; then
    # Bazzite has no cloud image: build one from the official container with bootc-image-builder (Universal Blue's own way)
    echo "building bazzite.qcow2 (pulls ghcr.io/ublue-os/bazzite:stable, ~8 GB)"
    mkdir -p bazzite/output
    printf '%s\n' 'FROM ghcr.io/ublue-os/bazzite:stable' \
        "RUN systemctl enable sshd && echo 'rice ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/rice && chmod 440 /etc/sudoers.d/rice" > bazzite/Containerfile
    printf '[[customizations.user]]\nname = "rice"\npassword = "rice"\nkey = "%s"\ngroups = ["wheel"]\n[customizations.disk]\nminsize = "40 GiB"\n' "$(cat id_vm.pub)" > bazzite/config.toml
    sudo podman build -q -t localhost/bazzite-test:latest bazzite
    sudo podman run --rm --privileged --security-opt label=type:unconfined_t -v "$W/bazzite/config.toml:/config.toml:ro" \
        -v "$W/bazzite/output:/output" -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest --type qcow2 --rootfs ext4 localhost/bazzite-test:latest
    sudo chown -R "$(id -u):$(id -g)" bazzite/output
    mv bazzite/output/qcow2/disk.qcow2 base/bazzite.qcow2 && echo "  done bazzite.qcow2"
fi
ls -lh base/
