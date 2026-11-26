#!/bin/bash
# Builds the FaradayOS Fedora edition live ISO inside a Fedora container.
# Works on any Linux PC with podman or docker (including your CachyOS PC).
# Output: out-fedora/FaradayOSv<version>.iso (version from fedora/VERSION)
#
# Unattended: asks for your sudo password once at the start, then needs nothing else.
# - Re-runs itself as root once, so no password prompt appears later (sudo timeouts can't bite).
# - Blocks sleep/suspend while it builds, so the PC doesn't nap half-way.
# - Retries once by itself if the build fails (mirror outages, e.g. RPM Fusion).
# - Writes everything to out-fedora/build.log and shows a desktop notification when done.
# Settings (optional): FEDORA=44  ATTEMPTS=2
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=$REPO/out-fedora

if [ "$(id -u)" -ne 0 ]; then
  echo "Your sudo password is needed once, now. After that you can walk away."
  exec sudo env FEDORA="${FEDORA:-44}" ATTEMPTS="${ATTEMPTS:-2}" "$0" "$@"
fi
# sudo sets SUDO_UID/SUDO_GID to the user who started the build
BUILD_UID=${SUDO_UID:-0}; BUILD_GID=${SUDO_GID:-0}

FEDORA=${FEDORA:-44}
ATTEMPTS=${ATTEMPTS:-2}
VERSION=$(tr -d '[:space:]' < "$REPO/fedora/VERSION")
ISO=FaradayOSv$VERSION.iso
VOLID=FaradayOSv${VERSION//./-}

if command -v podman >/dev/null; then ENGINE=podman
elif command -v docker >/dev/null; then ENGINE=docker
else echo "Install podman first:  sudo pacman -S podman"; exit 1; fi

mkdir -p "$OUT"
LOG=$OUT/build.log
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

notify() {  # best effort desktop notification for the user who started the build
  [ "$BUILD_UID" -ne 0 ] && command -v notify-send >/dev/null || return 0
  sudo -u "#$BUILD_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$BUILD_UID/bus" \
    notify-send -a FaradayOS "$1" "$2" 2>/dev/null || true
}
finish() {
  rc=$?
  # Hand the output (ISO and logs) back to you, also when the build fails
  chown -R "$BUILD_UID:$BUILD_GID" "$OUT" 2>/dev/null || true
  if [ $rc -eq 0 ]; then notify "FaradayOS ISO ready" "$OUT/$ISO"
  else notify "FaradayOS build failed" "See $LOG"; fi
}
trap finish EXIT

# Keep the PC awake while building (systemd-inhibit is part of systemd; skipped if missing)
INHIBIT=()
systemd-inhibit --what=sleep true >/dev/null 2>&1 && \
  INHIBIT=(systemd-inhibit --what=sleep:idle:handle-lid-switch --who=FaradayOS --why="Building the FaradayOS ISO" --mode=block)

build() {
  rm -rf "$OUT/result"
  # --network host: use the PC's own network and DNS. The default container network
  # (NAT bridge) gets no DNS answers on some PCs (firewall/VPN), which makes dnf fail
  # with "Could not resolve host" or "Resolving timed out".
  "${INHIBIT[@]}" $ENGINE run --rm --privileged --network host \
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
}

echo "Building $ISO (FaradayOS v$VERSION) with $ENGINE (Fedora $FEDORA). Takes 30-90 min, needs ~40 GB free."
echo "Started $(date '+%a %d %b %H:%M'). Log: $LOG"
for try in $(seq 1 "$ATTEMPTS"); do
  if build; then
    echo "Done $(date '+%a %d %b %H:%M'): $OUT/$ISO"
    exit 0
  fi
  echo "Build attempt $try of $ATTEMPTS failed $(date '+%H:%M')."
  [ "$try" -lt "$ATTEMPTS" ] && { echo "Retrying in 60 s (mirror outages usually clear)..."; sleep 60; }
done
echo "Build failed. Details: $LOG and $OUT/lmc.log"
exit 1
