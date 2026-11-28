# FaradayOS (Fedora edition): normal, writable Fedora system with the Ryoku desktop (Quickshell shell on the
# niri/Hyprland compositor). See fedora/quickshell/README.md.
# Built into a live ISO by fedora/build-iso.sh (livemedia-creator --no-virt).
# EDITIONS (fedora/editions.list): lines between "#@if <edition>..." and "#@end" are only in those editions;
# fedora/edition-ks.sh writes the kickstart for one edition. Everything else is shared, so fixes reach every edition.
#   performance = gaming, VR, KDE Plasma on TTY4      workplace = no gaming/VR/Plasma, office tools, software catalog
# The repo is mounted at /src inside the build container; branding is copied from there.

lang en_US.UTF-8
keyboard us
timezone Australia/Brisbane --utc
selinux --enforcing
firewall --enabled --service=mdns
network --bootproto=dhcp --device=link --activate
rootpw --lock
services --enabled=NetworkManager,ModemManager --disabled=sshd
bootloader --location=none
zerombr
clearpart --all
part / --size=20480 --fstype=ext4
shutdown

url --metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch
# Not named "updates" / "fedora-cisco-openh264": anaconda silently skips kickstart repos with those names
repo --name=fedora-updates --metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$releasever&arch=$basearch
repo --name=cisco-openh264 --metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-cisco-openh264-$releasever&arch=$basearch
repo --name=rpmfusion-free --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-$releasever&arch=$basearch
repo --name=rpmfusion-free-updates --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-$releasever&arch=$basearch
repo --name=rpmfusion-nonfree --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-$releasever&arch=$basearch
repo --name=rpmfusion-nonfree-updates --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-$releasever&arch=$basearch
#@if performance
repo --name=rpmfusion-nonfree-steam --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-steam-$releasever&arch=$basearch
#@end
# Ryoku desktop: its signed Fedora repo, and the Hyprland COPR limited to the packages Ryoku's installer takes from it
repo --name=ryoku --baseurl=https://repo.ryoku.dev/stable/fedora/$releasever/x86_64
repo --name=ryoku-copr-sdegler-hyprland --baseurl=https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-$releasever-$basearch/ --includepkgs=aquamarine,hyprcursor,hyprgraphics,hypridle,hyprland,hyprland-guiutils,hyprland-qt-support,hyprland-uwsm,hyprlang,hyprpicker,hyprpolkitagent,hyprsunset,hyprtoolkit,hyprutils,hyprwire,uwsm,xdg-desktop-portal-hyprland

%packages
# Live system and installer (from Fedora's fedora-live-base.ks)
kernel
kernel-modules
kernel-modules-extra
kernel-devel
memtest86+
anaconda
anaconda-install-env-deps
anaconda-live
@anaconda-tools
-fcoe-utils
-device-mapper-multipath
-sdubby
aajohan-comfortaa-fonts
dracut-live
glibc-all-langpacks
livesys-scripts

# Base desktop system (what the KDE environment group brought in, minus KDE itself)
@core
@standard
@hardware-support
@base-graphical
@fonts
@multimedia
@networkmanager-submodules
@printing
@guest-desktop-agents
# Desktops: Ryoku (Quickshell shell on Hyprland) logs in on TTY2, KDE Plasma on TTY4 (no graphical login screen;
# see fedora/quickshell/overlay/etc/profile.d/faraday-tty-session.sh)
ryoku
ryoku-keyring
ryoku-desktop
# Compositor: niri for now. Ryoku's Fedora 44 Hyprland packages are broken upstream (hyprglass needs
# libaquamarine.so.14, the COPR ships .so.15). When the probe workflow shows they install, change this line
# to ryoku-desktop-hyprland; tty-session then starts Hyprland on TTY2 by itself.
ryoku-desktop-niri
#@if performance
@kde-desktop
#@end
# Both editions: a PDF viewer, an image viewer and a calculator for the FaradayOS desktop (the performance
# edition had none: PDFs and pictures opened in Firefox or not at all; VM test, v0.93e). Defaults: etc/xdg/mimeapps.list
evince
loupe
gnome-calculator
#@if workplace
# Workplace: no KDE Plasma. More small GNOME apps for everyday files
gnome-text-editor
file-roller
simple-scan
xdg-desktop-portal-gtk
#@end
kitty
nautilus
nautilus-python
fish
btop
pavucontrol
pipewire-pulseaudio
wireplumber
gnome-keyring
xdg-user-dirs
# Installer (KDE group brought this in before) and everyday work apps
anaconda-webui
@libreoffice
firefox
fastfetch
papirus-icon-theme
# Dialogs for the add-ons installer and VR check (small; no Plasma)
kdialog
# rebrand-ryoku.py (FaradayOS branding over Ryoku, also run after every update)
python3

# Package repos stay enabled on the installed system
rpmfusion-free-release
rpmfusion-nonfree-release
fedora-workstation-repositories
libdnf5-plugin-actions

# Graphics: AMD and Intel use Mesa; NVIDIA uses RPM Fusion's driver
mesa-dri-drivers
mesa-vulkan-drivers
vulkan-tools
akmods
akmod-nvidia
#@if performance
# Steam is 32-bit: it needs the 32-bit NVIDIA libraries (already pulled in today; listed so it stays that way)
xorg-x11-drv-nvidia-libs.i686
#@end
switcheroo-control

# Laptops: touchpad, touchscreen, pen, screen rotation, fingerprint reader
libinput
xorg-x11-drv-libinput
libwacom
iio-sensor-proxy
linux-firmware
fprintd
fprintd-pam
libfprint

#@if performance
# Gaming
steam
gamemode
gamescope
mangohud
# Big optional software is NOT in the ISO; one-click installers in the app menu add it after setup:
#   "Install VR tools" (WiVRn, ALVR, SteamVR, xrizer, OpenComposite, NVIDIA NVENC/CUDA libs)
#   "Install Wine and Lutris"

# VR groundwork only (small): headset USB rules, mDNS discovery, firewall service, realtime permission tool
steam-devices
#@end
# mDNS: finds network printers, and VR headsets in performance
avahi
nss-mdns
libcap

# Full codecs from RPM Fusion instead of Fedora's limited ones
ffmpeg
-ffmpeg-free
-libavcodec-free
-libavdevice-free
-libavfilter-free
-libavformat-free
-libavutil-free
-libpostproc-free
-libswresample-free
-libswscale-free
# Hardware video decoding for AMD/Intel
mesa-va-drivers-freeworld
-mesa-va-drivers

# Boot splash
plymouth
plymouth-plugin-script
%end

# Give the chroot a working DNS so %post can download packages
%post --nochroot
R="${ANA_INSTALL_PATH:-/mnt/sysimage}/etc/resolv.conf"
if [ -L "$R" ]; then readlink "$R" > /tmp/faraday-resolv-link; fi
rm -f "$R"
cp -L /etc/resolv.conf "$R"
%end

# FaradayOS branding: boot splash, KDE splash, wallpaper, colours, login and lock screen
%post --nochroot --erroronfail
bash /src/fedora/apply-branding.sh "${ANA_INSTALL_PATH:-/mnt/sysimage}" /src
# Quickshell edition files: Ryoku/Hyprland repos for updates, TTY2/TTY4 desktops, live session
cp -a --no-preserve=ownership /src/fedora/quickshell/overlay/. "${ANA_INSTALL_PATH:-/mnt/sysimage}/"
chmod 755 "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/livesys/sessions.d/livesys-ryoku" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/share/faraday/rebrand-ryoku.py" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/faraday/tty-session" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/faraday/desktop-session" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/faraday/niri-session" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/faraday/ryogami-quiet" "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/share/faraday/no-ghost-popups.py"
%end

%post --erroronfail
set -x

#@if performance
echo performance > /usr/share/faraday/edition
# Keep the Steam repo on for updates
dnf config-manager setopt rpmfusion-nonfree-steam.enabled=1 || \
  sed -i '0,/^enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
#@end
#@if workplace
echo workplace > /usr/share/faraday/edition
#@end
# Add-ons catalog: keep only the categories meant for this edition ("[Name | edition ...]" headers in addons.list)
ED=$(cat /usr/share/faraday/edition)
awk -v ed="$ED" 'BEGIN { keep=1 }
  /^\[/ { keep=1; p=index($0, "|"); if (p) { e=substr($0, p+1); sub(/\].*/, "", e); keep=0; n=split(e, w, " "); for (i=1; i<=n; i++) if (w[i] == ed) keep=1 } }
  keep' /usr/share/faraday/addons.list > /tmp/addons.list
install -m644 /tmp/addons.list /usr/share/faraday/addons.list
grep -q '^\[' /usr/share/faraday/addons.list || exit 1

# Build the NVIDIA kernel module now, so it works on first boot of the live USB.
# Installing akmod-nvidia already starts a build in the background: wait for it, then build if it did not finish.
KVER=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)
for i in $(seq 180); do
  rpm -q "kmod-nvidia-$KVER" && break
  pgrep -x akmods >/dev/null || break
  sleep 5
done
pkill -x akmods || true
pkill -x rpmbuild || true
pkill -f 'install.*kmod-nvidia' || true
sleep 5
rpm -q "kmod-nvidia-$KVER" || timeout 30m akmods --force --kernels "$KVER"
rpm -q "kmod-nvidia-$KVER" || { echo "NVIDIA module build failed"; exit 1; }

# Fingerprint login and sudo (enrol in System Settings > Users)
authselect current >/dev/null 2>&1 || authselect select local --force
authselect enable-feature with-fingerprint
authselect apply-changes

#@if performance
# VR: open WiVRn/ALVR/mDNS ports, run the boot-time VR setup, let headsets find this PC
firewall-offline-cmd --add-service=faradayos-vr
Z=$(firewall-offline-cmd --get-default-zone)
[ "$Z" = FedoraWorkstation ] || firewall-offline-cmd --zone=FedoraWorkstation --add-service=faradayos-vr || true
systemctl enable avahi-daemon.service faraday-vr-setup.service
#@end
#@if workplace
# Workplace: no VR or gaming. Remove the VR tools that the shared overlay brings, and the gaming kernel settings.
rm -f /usr/bin/faraday-install-vr /usr/bin/faraday-steamvr-setup /usr/bin/faraday-vr-check /usr/libexec/faraday/install-vr-system \
  /usr/share/applications/faraday-install-vr.desktop /usr/share/applications/faraday-steamvr-setup.desktop \
  /usr/share/applications/faraday-vr-check.desktop /etc/xdg/autostart/faraday-vr-check.desktop \
  /usr/lib/systemd/system/faraday-vr-setup.service /usr/lib/firewalld/services/faradayos-vr.xml \
  /usr/lib/udev/rules.d/70-faradayos-vr.rules /etc/yum.repos.d/_copr-xr-sig-xrizer.repo \
  /usr/libexec/faraday/addon-ckan /etc/sysctl.d/99-faraday-gaming.conf
rm -rf /usr/share/faraday/vr
# Printers on the network are found through mDNS
systemctl enable avahi-daemon.service
#@end

# Keep the ISO small: remove large extras that office/desktop work does not need (dnf install them if wanted).
# Done here, not in %packages, because they are members of the KDE/LibreOffice groups.
# (Java stays: with Fedora updates, LibreOffice 26.2 needs it, and removing it takes LibreOffice too)
dnf -y remove 'digikam*' 'proj-data-*' libreoffice-base || true
rpm -q libreoffice-writer libreoffice-calc libreoffice-impress nautilus kitty || exit 1
rpm -q evince loupe gnome-calculator || exit 1
# App store: Flathub, the catalog the FaradayOS Store installs from (only Fedora's own flatpak remote was set up,
# so every install from the Store failed; VM test, v0.93e)
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || exit 1
# The NVIDIA settings loader autostarts in every session; on PCs without the NVIDIA driver it failed at each sign-in
# (usr/libexec/faraday/nvidia-settings-load runs it only when the driver is loaded)
for f in /etc/xdg/autostart/nvidia-settings*.desktop; do
  if [ -f "$f" ]; then sed -i 's|^Exec=nvidia-settings -l$|Exec=/usr/libexec/faraday/nvidia-settings-load|' "$f"; fi
done
#@if performance
# Both desktops must be in the image: FaradayOS (Ryoku on Hyprland or niri) on TTY2, KDE Plasma on TTY4
rpm -q ryoku-desktop plasma-workspace || exit 1
#@end
#@if workplace
# Workplace: FaradayOS desktop only, no Plasma, no Steam
rpm -q ryoku-desktop evince || exit 1
rpm -q plasma-workspace && exit 1
rpm -q steam && exit 1
#@end
rpm -q hyprland || rpm -q niri || exit 1

# Live session: liveuser is signed in on TTY2, which starts the FaradayOS (Hyprland) desktop (fedora/quickshell/overlay/usr/libexec/livesys/sessions.d)
test -x /usr/libexec/livesys/sessions.d/livesys-ryoku || exit 1
systemctl enable livesys.service livesys-late.service
echo 'livesys_session="ryoku"' > /etc/sysconfig/livesys

# Ryoku desktop setup (what Ryoku's own installer does, done once for every future user)
# Trust Ryoku's repo for updates only if ryoku-keyring holds Ryoku's published signing key
gpg --batch --with-colons --show-keys /etc/pki/rpm-gpg/RPM-GPG-KEY-ryoku | grep -q '^fpr:*EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3:' || exit 1
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ryoku
# Each user's Ryoku config is laid down at their first login, by Ryoku's session launcher (tty-session) before niri
# starts. ryoku-bootstrap.service stays pulled in by niri.service (it skips itself once the config exists), but is not
# enabled for every login: started with the user manager it ran a second copy of the same config copy at the same time
# and failed on the first sign-in (rename ... .ryoku-tmp: no such file).
systemctl --global disable ryoku-bootstrap.service 2>/dev/null || true
mkdir -p /usr/share/icons/default
[ -e /usr/share/icons/default/index.theme ] || printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Ice\n' > /usr/share/icons/default/index.theme
# Graphical login screen: Ryoku's SDDM greeter (weston kiosk + its "orbital" skin, laid by ryoku-desktop),
# with sessions "FaradayOS" (default) and "KDE Plasma" (usr/share/wayland-sessions/faradayos*.desktop;
# rebrand-ryoku.py hides the packages' own entries). Lists every user, no autologin. Config in
# etc/sddm.conf.d. Fedora KDE's own login screen (plasmalogin) stays off. TTY2/TTY4 keep a text sign-in
# as a fallback (usr/libexec/faraday/tty-session); the live USB signs liveuser in on TTY2 (livesys-ryoku).
[ -f /usr/share/sddm/themes/ryoku/Main.qml ] || /usr/share/ryoku/lockscreen/qylock/sddm-host/install-greeter-theme \
  /usr/share/ryoku/lockscreen/qylock/themes/clockwork/orbital /usr/share/sddm/themes/ryoku false
test -f /usr/share/sddm/themes/ryoku/Main.qml || exit 1
test -x /usr/share/ryoku/lockscreen/ryoku-greeter || exit 1
systemctl disable plasmalogin.service 2>/dev/null || true
rm -f /etc/systemd/system/display-manager.service
systemctl enable sddm.service ryoku-greeter-guard.service
test "$(readlink /etc/systemd/system/display-manager.service)" = /usr/lib/systemd/system/sddm.service || exit 1
systemctl enable getty@tty2.service getty@tty4.service
# First sign-in on this PC starts the FaradayOS desktop (SDDM remembers each later choice)
mkdir -p /var/lib/sddm
printf '[Last]\nSession=/usr/share/wayland-sessions/faradayos.desktop\n' > /var/lib/sddm/state.conf
chown -R sddm:sddm /var/lib/sddm || true
# No graphical login screen means Fedora KDE's first-boot account setup (plasma-setup) never runs, so the
# installer itself asks for the user account (etc/anaconda/conf.d/90-faradayos-accounts.conf)
systemctl disable plasma-setup.service 2>/dev/null || true
grep -q anaconda-screen-network /etc/anaconda/conf.d/90-faradayos-accounts.conf || exit 1
# Keep the FaradayOS boot menu and boot splash (Ryoku's package themes GRUB and Plymouth as its own)
/usr/bin/ryoku-grub-menu purge || true
# FaradayOS branding over the Ryoku desktop: names, logos, wallpaper, bar mark, fastfetch.
# Runs again after every dnf update (etc/dnf/libdnf5-plugins/actions.d/zz-faraday-rebrand-ryoku.actions).
FARADAY_NO_MKCONFIG=1 /usr/share/faraday/rebrand-ryoku.py
/usr/share/faraday/rebrand-ryoku.py --check || exit 1

# Installer starting keyboard layout (see /usr/share/glib-2.0/schemas/90_faradayos-keyboard.gschema.override)
glib-compile-schemas /usr/share/glib-2.0/schemas

# FaradayOS branding stays after updates
systemctl enable faraday-rebrand.service
# Installed systems start at the login screen: the installer and first boot remove the live user and its autologin
systemctl enable faraday-remove-liveuser.service
plymouth-set-default-theme faraday
/usr/share/faraday/rebrand-fedora.sh

systemctl set-default graphical.target
rm -f /var/lib/rpm/__db*
dnf clean all
%end

# Put back Fedora's own DNS setup (systemd-resolved link)
%post --nochroot
R="${ANA_INSTALL_PATH:-/mnt/sysimage}/etc/resolv.conf"
rm -f "$R"
if [ -s /tmp/faraday-resolv-link ]; then ln -s "$(cat /tmp/faraday-resolv-link)" "$R"; fi
%end
