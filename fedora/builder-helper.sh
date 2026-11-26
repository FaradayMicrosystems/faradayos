#!/bin/bash
# FaradayOS Builder: the part that runs as root (started once by the Builder app through pkexec, so one
# password or fingerprint covers the whole session). It runs from the FaradayOS source the app downloaded,
# never from inside the AppImage (root cannot read a user's AppImage mount).
#
# Reads one command per line on stdin and only accepts these:
#   build <edition> <output folder>   run fedora/build-iso.sh <edition> (edition must be in editions.list)
#   install-podman                    install podman with this distro's package manager
#   fingerprint                       let the sign-in dialog accept a fingerprint (pam_fprintd in polkit-1)
#   stop                              stop the running build
#   quit
# Writes "@@READY" when started and "@@DONE <command> <exit code>" after each command.
# Closing the app (end of stdin) stops a running build.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "builder-helper: must run as root (through pkexec)"; exit 1; }
SRC=$(cd "$(dirname "$0")/.." && pwd)
USER_UID=${PKEXEC_UID:-${SUDO_UID:-0}}
export PKEXEC_UID=$USER_UID
if command -v podman >/dev/null; then ENGINE=podman; elif command -v docker >/dev/null; then ENGINE=docker; else ENGINE=""; fi

editions() { grep -v '^[[:space:]]*#' "$SRC/fedora/editions.list" | cut -d'|' -f1 | tr -d ' ' | grep .; }

stop_build() { # stop build-iso.sh and its container
  [ -n "${BPID:-}" ] || return 0
  kill -TERM -- "-$BPID" 2>/dev/null || kill -TERM "$BPID" 2>/dev/null
  [ -n "$ENGINE" ] && "$ENGINE" rm -f "faradayos-build-$CUR_ED" >/dev/null 2>&1
  wait "$BPID" 2>/dev/null
  echo "Build stopped."
}

build() { # edition outdir
  local ed=$1 out=$2 line rc
  CUR_ED=$ed
  editions | grep -qx -- "$ed" || { echo "Unknown edition: $ed"; return 2; }
  case $out in /*) ;; *) echo "Output folder must be a full path: $out"; return 2 ;; esac
  # The output folder must belong to the person who signed in (never a system folder)
  mkdir -p "$out" 2>/dev/null || sudo -u "#$USER_UID" mkdir -p "$out" || return 2
  [ "$(stat -c %u "$out")" = "$USER_UID" ] || { echo "Output folder $out is not yours; pick a folder in your home folder."; return 2; }
  # Own process group, so stop can end the whole build
  FARADAY_OUT=$out ATTEMPTS=${ATTEMPTS:-2} setsid bash "$SRC/fedora/build-iso.sh" "$ed" </dev/null &
  BPID=$!
  # Watch stdin while building: "stop" or the app closing (end of input) stops the build
  while kill -0 "$BPID" 2>/dev/null; do
    if IFS= read -r -t 2 line; then
      [ "$line" = stop ] && { stop_build; BPID=""; return 130; }
    else
      rc=$?
      if [ "$rc" -le 128 ]; then stop_build; BPID=""; exit 0; fi
    fi
  done
  wait "$BPID"; rc=$?; BPID=""
  return $rc
}

install_podman() {
  . /etc/os-release 2>/dev/null
  case " ${ID:-} ${ID_LIKE:-} " in
    *" arch "*) pacman -S --needed --noconfirm podman ;;
    *" fedora "*|*" rhel "*|*" centos "*) dnf -y install podman ;;
    *" debian "*|*" ubuntu "*) apt-get update && apt-get install -y podman ;;
    *" suse "*|*" opensuse "*) zypper --non-interactive install podman ;;
    *) echo "Unknown distribution (${ID:-?}): install podman with your package manager."; return 2 ;;
  esac
}

fingerprint() {
  local f=/etc/pam.d/polkit-1 mod=""
  for d in /usr/lib/security /usr/lib64/security /lib/security /usr/lib/x86_64-linux-gnu/security /lib/x86_64-linux-gnu/security; do
    [ -e "$d/pam_fprintd.so" ] && mod=1
  done
  [ -n "$mod" ] || { echo "pam_fprintd is not installed (package fprintd). Install it, enroll a finger, then try again."; return 2; }
  if [ ! -e "$f" ]; then
    for v in /usr/lib/pam.d/polkit-1 /usr/share/polkit-1/pam/polkit-1; do [ -e "$v" ] && cp "$v" "$f" && break; done
  fi
  [ -f "$f" ] || { echo "No $f on this system: fingerprint sign-in is not supported here."; return 2; }
  grep -q pam_fprintd "$f" && { echo "Fingerprint sign-in is already on ($f)."; return 0; }
  cp -a "$f" "$f.faradayos-backup"
  # First auth line: a fingerprint is enough; if it fails or times out, the password still works
  awk 'BEGIN{d=0} !d && /^[[:space:]]*-?auth/ { print "auth       sufficient   pam_fprintd.so"; d=1 } { print }' "$f.faradayos-backup" > "$f.new" &&
    grep -q pam_fprintd "$f.new" && mv "$f.new" "$f" && chmod 644 "$f"
  echo "Fingerprint sign-in is on. Backup of the old file: $f.faradayos-backup"
}

trap 'stop_build; exit 143' TERM
echo "@@READY"
while read -r cmd arg1 arg2; do
  case $cmd in
    build) build "$arg1" "$arg2"; echo "@@DONE build $?" ;;
    install-podman) install_podman; rc=$?
      command -v podman >/dev/null && ENGINE=podman
      echo "@@DONE install-podman $rc" ;;
    fingerprint) fingerprint; echo "@@DONE fingerprint $?" ;;
    stop) echo "@@DONE stop 0" ;;
    quit) exit 0 ;;
    "") ;;
    *) echo "Unknown command: $cmd"; echo "@@DONE $cmd 2" ;;
  esac
done
exit 0
