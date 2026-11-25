# VM tests

Checks that `install.sh` turns a clean distro into a working desktop: a fresh cloud image with nothing on it, the rice copied in, `./install.sh` run without questions (`RICE_EDITION=pc RICE_GPU=other`), then every tool, the font, the Hyprland session, the generated config and `Hyprland --verify-config` are checked.

Needs `qemu`, `qemu-img`, `cloud-image-utils` (for `cloud-localds`) and KVM. Bazzite also needs `podman` and sudo, because its disk is built from the official image with `bootc-image-builder`.

```sh
tests/vm/images.sh                 # download / build the clean images (~10 GB with Bazzite; NO_BAZZITE=1 skips it)
tests/vm/test.sh arch 2201         # one distro: fresh VM, install, checks, power off
tests/vm/test.sh fedora 2203
tests/vm/test.sh ubuntu26 2205
MEM=6144 tests/vm/test.sh bazzite 2204   # install, reboot, install again
```

Images and logs live in `~/Projects/wire-vmtest` (override with `WIRE_VMTEST`). Each run starts from a throwaway copy, so the base images stay clean.

- `KEEP=1` leaves the VM running afterwards. `REUSE=1 tests/vm/vm.sh <distro> <port>` boots that same disk again.
- `tests/vm/shot.py <distro> out.png` takes a screenshot of the VM's screen; `tests/vm/vmhypr.sh <port> '<cmd>'` runs a command inside its Hyprland session. The screenshots in `docs/screenshots` were taken this way, on a freshly installed Arch VM.
