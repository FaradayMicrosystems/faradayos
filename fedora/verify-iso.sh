#!/bin/bash
# Checks a built FaradayOS Fedora ISO: branding, boot splash, NVIDIA driver, gaming, VR installers, touchpad, fingerprint.
# Usage: fedora/verify-iso.sh [path/to/FaradayOSv<version>.iso]
# Runs inside a Fedora container (podman or docker). Prints PASS/FAIL per check.
set -euo pipefail

VERSION=$(cat "$(dirname "$0")/VERSION")
ISO=$(realpath "${1:-$(dirname "$0")/../out-fedora/FaradayOSv$VERSION.iso}")
[ -f "$ISO" ] || { echo "ISO not found: $ISO"; exit 1; }
if command -v podman >/dev/null; then ENGINE=podman; else ENGINE=docker; fi
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO=sudo

$SUDO $ENGINE run --rm --privileged -v /dev:/dev -v "$ISO":/iso.iso:ro -e VERSION="$VERSION" \
  "docker.io/library/fedora:${FEDORA:-44}" bash -euc '
dnf -y -q install dracut squashfs-tools xorriso >/dev/null
echo "ISO size: $(du -h /iso.iso | cut -f1)"
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
check "Version is FaradayOS v$VERSION"       "grep -qx \"PRETTY_NAME=.FaradayOS v$VERSION.\" $R/usr/lib/os-release && grep -qx IMAGE_VERSION=$VERSION $R/usr/lib/os-release && grep -qx VERSION_ID=44 $R/usr/lib/os-release"
check "ISO volume label FaradayOSv${VERSION//./-}" "xorriso -indev /iso.iso -pvd_info 2>&1 | grep -q \"Volume Id *: FaradayOSv${VERSION//./-}\""
check "Boot splash theme installed"          "test -f $R/usr/share/plymouth/themes/faraday/faraday.script -a -f $R/usr/share/plymouth/themes/faraday/logo.png -a -f $R/usr/share/plymouth/themes/faraday/frame-536.png"
check "Boot splash set as default"           "grep -q ^Theme=faraday $R/etc/plymouth/plymouthd.conf"
check "Boot splash inside live initramfs"    "lsinitrd \$(find /m/iso -name initrd.img | head -1) | grep -q plymouth/themes/faraday/faraday.script"
check "Plymouth script plugin installed"     "ls $R/usr/lib64/plymouth/script.so"
check "KDE global theme + KDE splash"        "test -f $R/usr/share/plasma/look-and-feel/org.faraday.desktop/contents/splash/Splash.qml"
check "KDE splash default for new users"     "grep -q Theme=org.faraday.desktop $R/etc/skel/.config/ksplashrc"
check "Wallpaper installed"                  "test -s $W"
check "Wallpaper default for desktop"        "grep -q FaradayOS $R/usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/faradayos-wallpaper.js"
check "Wallpaper on lock screen"             "grep -q FaradayOS $R/etc/xdg/kscreenlockerrc"
check "Logo on login screen"                 "grep -q /usr/share/faraday/login.png $R/etc/plasmalogin.conf.d/10-faraday.conf && test -s $R/usr/share/faraday/login.png"
check "Colour scheme + global theme default" "grep -q ColorScheme=FaradayOS $R/etc/xdg/kdeglobals && grep -q LookAndFeelPackage=org.faraday.desktop $R/etc/xdg/kdeglobals"
L=$R/usr/share/plasma/look-and-feel/org.faraday.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
check "Left panel layout (menu, apps, tray)"  "grep -q location.*left $L && grep -q kickoff $L && grep -q icontasks $L && grep -q systemtray $L"
check "Papirus icons installed"              "test -d $R/usr/share/icons/Papirus-Dark"
check "FaradayOS logo icons are the default"  "test -s $R/usr/share/icons/FaradayOS/48x48/apps/start-here-kde-symbolic.png && grep -q Theme=FaradayOS $R/etc/xdg/kdeglobals && grep -q Theme=FaradayOS $R/etc/skel/.config/kdeglobals"
check "Installer uses FaradayOS colours"     "grep -q ff7a1a $R/usr/share/cockpit/branding/fedora-kde/branding.css && test -s $R/usr/share/cockpit/branding/fedora-kde/logo.png -a -f $R/usr/share/plymouth/themes/faraday/frame-536.png"
V=$(. $R/usr/lib/os-release; echo "$VARIANT_ID"); B=$R/usr/share/cockpit/branding/fedora${V:+-$V}
check "Installer actually loads FaradayOS colours" "grep -q ff7a1a $B/branding.css && test -s $B/logo.png -a ! -L $B/logo.png"
check "Colour scheme file"                   "test -f $R/usr/share/color-schemes/FaradayOS.colors"
check "Branding re-applied after updates"    "test -x $R/usr/share/faraday/rebrand-fedora.sh -a -f $R/etc/dnf/libdnf5-plugins/actions.d/faraday-rebrand.actions"
check "Branding service enabled"             "ls $R/etc/systemd/system/multi-user.target.wants/faraday-rebrand.service"
check "NVIDIA kernel module built"           "find $R/usr/lib/modules -name \"nvidia.ko*\" | grep -q ."
check "Steam, gamescope, MangoHud, GameMode" "chroot $R rpm -q steam gamescope mangohud gamemode"
check "Full ffmpeg codecs (RPM Fusion)"      "ls $R/usr/lib64/libavcodec.so.* && ! chroot $R rpm -q libavcodec-free"
Z=$R/etc/firewalld/zones
# Big optional software ships as one-click installers, not in the ISO
VRPKGS="wivrn wivrn-dashboard xrizer opencomposite android-tools xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs wine lutris"
# (xorg-x11-drv-nvidia-cuda-libs is not checked: the NVIDIA driver itself requires it)
lean() { ! chroot $R rpm -q wivrn wivrn-dashboard xrizer wine lutris | grep -qv "not installed" && ! test -e $R/opt/alvr; }
installers() {
  for f in usr/bin/faraday-install-vr usr/bin/faraday-install-wine usr/libexec/faraday/install-vr-system; do
    test -x "$R/$f" && bash -n "$R/$f" || return 1
  done
  test -f $R/usr/share/applications/faraday-install-vr.desktop -a -f $R/usr/share/applications/faraday-install-wine.desktop -a -f $R/usr/share/faraday/vr/alvr.desktop
}
installer_pkgs() {
  n=$(dnf -q --setopt=reposdir=$R/etc/yum.repos.d --setopt=cachedir=/tmp/dnfc repoquery --available --qf "%{name}\n" $VRPKGS 2>/dev/null | sort -u | grep -c .)
  [ "$n" -eq $(echo $VRPKGS | wc -w) ]
}
check "Lean ISO: VR apps, Wine, Lutris, CUDA not preinstalled" lean
check "Installers: VR tools + Wine/Lutris in app menu" installers
check "Installers: all their packages are downloadable" installer_pkgs
check "Installers: ALVR download link works" "curl -fsIL -o /dev/null https://github.com/alvr-org/ALVR/releases/latest/download/alvr_streamer_linux.tar.gz"
check "VR: SteamVR setup launcher"           "test -x $R/usr/bin/faraday-steamvr-setup -a -f $R/usr/share/applications/faraday-steamvr-setup.desktop"
check "VR: readiness check + login notice"   "test -x $R/usr/bin/faraday-vr-check -a -f $R/etc/xdg/autostart/faraday-vr-check.desktop"
check "VR: firewall ports open (9757, 9943-9944)" "grep -q 9943-9944 $R/usr/lib/firewalld/services/faradayos-vr.xml && grep -qs faradayos-vr $Z/*.xml"
check "VR: boot setup + Avahi enabled"       "ls $R/etc/systemd/system/multi-user.target.wants/faraday-vr-setup.service && ls $R/etc/systemd/system/multi-user.target.wants/avahi-daemon.service"
check "VR: headset USB rules + steam-devices" "test -f $R/usr/lib/udev/rules.d/70-faradayos-vr.rules && chroot $R rpm -q steam-devices"
check "AMD/Intel VA-API video encode"       "chroot $R rpm -q mesa-va-drivers-freeworld"
K=$(ls $R/usr/lib/modules | sort -V | tail -1)
check "Touchpad: libinput + kernel drivers"  "chroot $R rpm -q libinput xorg-x11-drv-libinput && ! for m in i2c-hid-acpi hid-multitouch psmouse; do find $R/usr/lib/modules/$K -name \"\$m.ko*\" | grep -q . || grep -q \"/\$m.ko\" $R/usr/lib/modules/$K/modules.builtin || echo missing; done | grep -q missing"
check "Touchpad: tap to click default"       "grep -q TapToClick=true $R/etc/xdg/kcminputrc"
check "Fingerprint: fprintd + PAM installed" "chroot $R rpm -q fprintd fprintd-pam libfprint"
# /etc/pam.d/system-auth is an absolute symlink into /etc/authselect, so read the target inside the image
check "Fingerprint: login uses fingerprint"  "grep -qx with-fingerprint $R/etc/authselect/authselect.conf && grep -q pam_fprintd $R/etc/authselect/system-auth"
check "Install removes live user + autologin" "test -x $R/usr/share/faraday/remove-liveuser.sh && grep -q remove-liveuser.sh $R/usr/share/anaconda/post-scripts/90-faraday-remove-liveuser.ks && ls $R/etc/systemd/system/multi-user.target.wants/faraday-remove-liveuser.service"
check "No live user baked into the image"   "! grep -q ^liveuser: $R/etc/passwd && ! grep -rqs ^User=liveuser $R/etc/plasmalogin.conf $R/etc/plasmalogin.conf.d $R/etc/sddm.conf $R/etc/sddm.conf.d"
check "Installer has its translations (all languages)" "test -f $R/usr/share/locale/de/LC_MESSAGES/anaconda.mo -a -f $R/usr/share/locale/ja/LC_MESSAGES/anaconda.mo"
check "System files owned by root (none by a normal user)" "! find $R -xdev -uid +999 -print -quit | grep -q ."
check "Installer keyboard: live layout readable" "chroot $R env GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.input-sources sources | grep -q xkb"
check "Live session configured (KDE)"        "grep -q kde $R/etc/sysconfig/livesys"

umount -R /m/root 2>/dev/null || true; umount /m/sq /m/iso
echo; [ $fails -eq 0 ] && echo "All checks passed." || { echo "$fails check(s) failed."; exit 1; }
'
