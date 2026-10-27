#!/bin/bash
# Checks a built FaradayOS Fedora ISO: branding, boot splash, NVIDIA driver, gaming apps.
# Usage: fedora/verify-iso.sh [path/to/FaradayOS-Fedora-44.iso]
# Runs inside a Fedora container (podman or docker). Prints PASS/FAIL per check.
set -euo pipefail

ISO=$(realpath "${1:-$(dirname "$0")/../out-fedora/FaradayOS-Fedora-${FEDORA:-44}.iso}")
[ -f "$ISO" ] || { echo "ISO not found: $ISO"; exit 1; }
if command -v podman >/dev/null; then ENGINE=podman; else ENGINE=docker; fi
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO=sudo

$SUDO $ENGINE run --rm --privileged -v /dev:/dev -v "$ISO":/iso.iso:ro \
  "docker.io/library/fedora:${FEDORA:-44}" bash -euc '
dnf -y -q install dracut squashfs-tools >/dev/null
mkdir -p /m/iso /m/sq /m/root
mount -o loop,ro /iso.iso /m/iso
mount -o loop,ro /m/iso/LiveOS/squashfs.img /m/sq
if [ -f /m/sq/LiveOS/rootfs.img ]; then mount -o loop,ro /m/sq/LiveOS/rootfs.img /m/root; R=/m/root; else R=/m/sq; fi

fails=0
check() { # description, command
  if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fails=$((fails+1)); fi
}
W=$R/usr/share/wallpapers/FaradayOS/contents/images/3260x1838.png
check "OS name is FaradayOS"                 "grep -q ^NAME=\\\"FaradayOS\\\" $R/usr/lib/os-release"
check "Boot splash theme installed"          "test -f $R/usr/share/plymouth/themes/faraday/faraday.script -a -f $R/usr/share/plymouth/themes/faraday/logo.png"
check "Boot splash set as default"           "grep -q ^Theme=faraday $R/etc/plymouth/plymouthd.conf"
check "Boot splash inside live initramfs"    "lsinitrd \$(find /m/iso -name initrd.img | head -1) | grep -q plymouth/themes/faraday/faraday.script"
check "Plymouth script plugin installed"     "ls $R/usr/lib64/plymouth/script.so"
check "KDE global theme + KDE splash"        "test -f $R/usr/share/plasma/look-and-feel/org.faraday.desktop/contents/splash/Splash.qml"
check "KDE splash default for new users"     "grep -q Theme=org.faraday.desktop $R/etc/skel/.config/ksplashrc"
check "Wallpaper installed"                  "test -s $W"
check "Wallpaper default for desktop"        "grep -q FaradayOS $R/usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/faradayos-wallpaper.js"
check "Wallpaper on lock screen"             "grep -q FaradayOS $R/etc/xdg/kscreenlockerrc"
check "Wallpaper on login screen"            "grep -q FaradayOS $R/etc/plasmalogin.conf.d/10-faraday.conf"
check "Colour scheme + global theme default" "grep -q ColorScheme=FaradayOS $R/etc/xdg/kdeglobals && grep -q LookAndFeelPackage=org.faraday.desktop $R/etc/xdg/kdeglobals"
L=$R/usr/share/plasma/look-and-feel/org.faraday.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
check "Left panel layout (menu, apps, tray)"  "grep -q location.*left $L && grep -q kickoff $L && grep -q icontasks $L && grep -q systemtray $L"
check "Papirus icons installed + default"    "test -d $R/usr/share/icons/Papirus-Dark && grep -q Theme=Papirus-Dark $R/etc/xdg/kdeglobals && grep -q Theme=Papirus-Dark $R/etc/skel/.config/kdeglobals"
check "Colour scheme file"                   "test -f $R/usr/share/color-schemes/FaradayOS.colors"
check "Branding re-applied after updates"    "test -x $R/usr/share/faraday/rebrand-fedora.sh -a -f $R/etc/dnf/libdnf5-plugins/actions.d/faraday-rebrand.actions"
check "Branding service enabled"             "ls $R/etc/systemd/system/multi-user.target.wants/faraday-rebrand.service"
check "NVIDIA kernel module built"           "find $R/usr/lib/modules -name \"nvidia.ko*\" | grep -q ."
check "Steam, gamescope, MangoHud, Lutris"  "chroot $R rpm -q steam gamescope mangohud lutris"
check "Full ffmpeg codecs (RPM Fusion)"      "ls $R/usr/lib64/libavcodec.so.* && ! chroot $R rpm -q libavcodec-free"
check "Live session configured (KDE)"        "grep -q kde $R/etc/sysconfig/livesys"

umount -R /m/root 2>/dev/null || true; umount /m/sq /m/iso
echo; [ $fails -eq 0 ] && echo "All checks passed." || { echo "$fails check(s) failed."; exit 1; }
'
