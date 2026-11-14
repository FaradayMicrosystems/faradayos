#!/bin/bash
# Builds the FaradayOS Fedora edition live ISO inside a Fedora container.
# Works on any Linux PC with podman or docker (including your CachyOS PC).
# Output: out-fedora/FaradayOSv<version>.iso (version from fedora/VERSION)
set -euo pipefail

FEDORA=${FEDORA:-44}
REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=$REPO/out-fedora
VERSION=$(cat "$REPO/fedora/VERSION")
ISO=FaradayOSv$VERSION.iso
VOLID=FaradayOSv${VERSION//./-}

if command -v podman >/dev/null; then ENGINE=podman
elif command -v docker >/dev/null; then ENGINE=docker
else echo "Install podman first:  sudo pacman -S podman"; exit 1; fi

SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO=sudo
if [ -n "$SUDO" ]; then
  # Ask for the password once, now, and keep sudo alive for the whole build,
  # so no prompt appears (and times out) while you are away.
  echo "Your sudo password is needed once, now. After that you can walk away."
  sudo -v
  while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null || true; sleep 50; done &
fi
mkdir -p "$OUT"
$SUDO rm -rf "$OUT/result"
# Hand the output (ISO and logs) back to you, also when the build fails
trap '$SUDO chown -R "$(id -u):$(id -g)" "$OUT"' EXIT

echo "Building $ISO (FaradayOS v$VERSION) with $ENGINE (Fedora $FEDORA). Takes 30-90 min, needs ~40 GB free."
# --network host: use the PC's own network and DNS. The default container network
# (NAT bridge) gets no DNS answers on some PCs (firewall/VPN), which makes dnf fail
# with "Could not resolve host" or "Resolving timed out".
$SUDO $ENGINE run --rm --privileged --network host \
  -v /dev:/dev -v "$REPO":/src:ro -v "$OUT":/out \
  "docker.io/library/fedora:$FEDORA" bash -euc "
    dnf -y install lorax-lmc-novirt pykickstart policycoreutils
    # The Fedora container image keeps only English translations (rpm macro %_install_langs).
    # Without this line the ISO inherits that: the installer finds no languages and crashes the live session.
    rm -f /etc/rpm/macros.image-language-conf
    ksvalidator /src/fedora/faradayos.ks
    livemedia-creator --make-iso --no-virt --iso-only --isfinal \
      --ks /src/fedora/faradayos.ks \
      --project FaradayOS --releasever $FEDORA --volid $VOLID \
      --iso-name $ISO \
      --compression xz --compress-arg=-Xbcj --compress-arg=x86 --compress-arg=-b --compress-arg=1M \
      --extra-boot-args 'rd.driver.blacklist=nouveau modprobe.blacklist=nouveau' \
      --resultdir /out/result --logfile /out/lmc.log
    mv /out/result/$ISO /out/$ISO
    cd /out && sha256sum $ISO > $ISO.sha256
  "
echo "Done: $OUT/$ISO"
