#!/bin/bash
# Builds the FaradayOS Fedora edition live ISO inside a Fedora container.
# Works on any Linux PC with podman or docker (including your CachyOS PC).
# Output: out-fedora/FaradayOS-Fedora-<version>.iso
set -euo pipefail

FEDORA=${FEDORA:-44}
REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=$REPO/out-fedora
ISO=FaradayOS-Fedora-$FEDORA.iso

if command -v podman >/dev/null; then ENGINE=podman
elif command -v docker >/dev/null; then ENGINE=docker
else echo "Install podman first:  sudo pacman -S podman"; exit 1; fi

SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO=sudo
mkdir -p "$OUT"
$SUDO rm -rf "$OUT/result"
# Hand the output (ISO and logs) back to you, also when the build fails
trap '$SUDO chown -R "$(id -u):$(id -g)" "$OUT"' EXIT

echo "Building $ISO with $ENGINE (Fedora $FEDORA). Takes 30-90 min, needs ~40 GB free."
$SUDO $ENGINE run --rm --privileged \
  -v /dev:/dev -v "$REPO":/src:ro -v "$OUT":/out \
  "docker.io/library/fedora:$FEDORA" bash -euc "
    dnf -y install lorax-lmc-novirt pykickstart policycoreutils
    ksvalidator /src/fedora/faradayos.ks
    livemedia-creator --make-iso --no-virt --iso-only --isfinal \
      --ks /src/fedora/faradayos.ks \
      --project FaradayOS --releasever $FEDORA --volid FaradayOS-$FEDORA \
      --iso-name $ISO \
      --extra-boot-args 'rd.driver.blacklist=nouveau modprobe.blacklist=nouveau' \
      --resultdir /out/result --logfile /out/lmc.log
    mv /out/result/$ISO /out/$ISO
    cd /out && sha256sum $ISO > $ISO.sha256
  "
echo "Done: $OUT/$ISO"
