#!/bin/bash
# Copies FaradayOS branding into a Fedora root.
# Usage: apply-branding.sh <target-root> <repo-dir>
# Branding files are shared with the CachyOS build (profile/airootfs); Fedora-only files live in fedora/overlay.
set -euo pipefail
ROOT=${1:?target root}
REPO=${2:?repo dir}
A=$REPO/profile/airootfs

copy() { # copy a file or folder from profile/airootfs to the same path in ROOT
  [ -e "$A/$1" ] || { echo "apply-branding: missing $A/$1" >&2; exit 1; }
  mkdir -p "$ROOT/$(dirname "$1")"
  cp -a "$A/$1" "$ROOT/$(dirname "$1")/"
}

# Boot splash (Plymouth)
copy usr/share/plymouth/themes/faraday
# KDE global theme, login splash, colours, wallpaper, logo
copy usr/share/plasma/look-and-feel/org.faraday.desktop
copy usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/faradayos-wallpaper.js
copy usr/share/wallpapers/FaradayOS
copy usr/share/color-schemes/FaradayOS.colors
copy usr/share/pixmaps/faradayos.png
# Logo icon theme: FaradayOS logo on start menu, About and installer icons; Papirus Dark for the rest
copy usr/share/icons/FaradayOS
copy usr/share/faraday/logo.png
copy usr/share/faraday/login.png
copy usr/share/faraday/logo.txt
copy usr/share/faraday/theme
# System-wide and new-user defaults
copy etc/xdg/kdeglobals
copy etc/xdg/kscreenlockerrc
copy etc/skel/.config/kdeglobals
copy etc/skel/.config/ksplashrc
copy etc/skel/.config/kscreenlockerrc
copy etc/skel/.config/fastfetch
# Gaming kernel settings
copy etc/sysctl.d/99-faraday-gaming.conf

# Fedora-only files: rebrand script, its boot service and dnf hook, login screen wallpaper, VR setup
cp -a "$REPO/fedora/overlay/." "$ROOT/"
chmod 755 "$ROOT/usr/share/faraday/rebrand-fedora.sh" "$ROOT/usr/bin/faraday-vr-check" "$ROOT/usr/bin/faraday-steamvr-setup"
# FaradayOS version (shown in os-release and About)
install -Dm644 "$REPO/fedora/VERSION" "$ROOT/usr/share/faraday/version"

echo "apply-branding: done"
