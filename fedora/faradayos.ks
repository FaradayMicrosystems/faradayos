# FaradayOS (Fedora edition), EXPERIMENTAL Quickshell branch: normal, writable Fedora system with the
# Ryoku desktop (Quickshell shell on the Hyprland compositor) instead of KDE Plasma. See fedora/quickshell/README.md.
# Built into a live ISO by fedora/build-iso.sh (livemedia-creator --no-virt).
# The repo is mounted at /src inside the build container; branding is copied from there.

lang en_US.UTF-8
keyboard us
timezone America/New_York
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
repo --name=updates --metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f$releasever&arch=$basearch
repo --name=fedora-cisco-openh264 --metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-cisco-openh264-$releasever&arch=$basearch
repo --name=rpmfusion-free --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-$releasever&arch=$basearch
repo --name=rpmfusion-free-updates --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-$releasever&arch=$basearch
repo --name=rpmfusion-nonfree --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-$releasever&arch=$basearch
repo --name=rpmfusion-nonfree-updates --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-$releasever&arch=$basearch
repo --name=rpmfusion-nonfree-steam --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-steam-$releasever&arch=$basearch
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
# Desktop: Ryoku (Quickshell shell on Hyprland), SDDM login screen, Ryoku's default apps
ryoku
ryoku-keyring
ryoku-desktop
ryoku-desktop-hyprland
sddm
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
# Steam is 32-bit: it needs the 32-bit NVIDIA libraries (already pulled in today; listed so it stays that way)
xorg-x11-drv-nvidia-libs.i686
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
# Quickshell edition files: Ryoku/Hyprland repos for updates, SDDM login screen, live session
cp -a --no-preserve=ownership /src/fedora/quickshell/overlay/. "${ANA_INSTALL_PATH:-/mnt/sysimage}/"
chmod 755 "${ANA_INSTALL_PATH:-/mnt/sysimage}/usr/libexec/livesys/sessions.d/livesys-hyprland"
%end

%post --erroronfail
set -x

# Keep the Steam repo on for updates
dnf config-manager setopt rpmfusion-nonfree-steam.enabled=1 || \
  sed -i '0,/^enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo

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

# VR: open WiVRn/ALVR/mDNS ports, run the boot-time VR setup, let headsets find this PC
firewall-offline-cmd --add-service=faradayos-vr
Z=$(firewall-offline-cmd --get-default-zone)
[ "$Z" = FedoraWorkstation ] || firewall-offline-cmd --zone=FedoraWorkstation --add-service=faradayos-vr || true
systemctl enable avahi-daemon.service faraday-vr-setup.service

# Keep the ISO small: remove large extras that office/desktop work does not need (dnf install them if wanted).
# Done here, not in %packages, because they are members of the KDE/LibreOffice groups.
dnf -y remove 'digikam*' 'proj-data-*' libreoffice-base 'java-*-openjdk*' || true
rpm -q libreoffice-writer libreoffice-calc libreoffice-impress nautilus kitty || exit 1
# This is the Quickshell edition: KDE Plasma must not be in the image
rpm -q plasma-workspace && exit 1

# Live session: liveuser logs straight into the Ryoku desktop (fedora/quickshell/overlay/usr/libexec/livesys/sessions.d)
test -x /usr/libexec/livesys/sessions.d/livesys-hyprland || exit 1
systemctl enable livesys.service livesys-late.service
echo 'livesys_session="hyprland"' > /etc/sysconfig/livesys

# Ryoku desktop setup (what Ryoku's own installer does, done once for every future user)
# Trust Ryoku's repo for updates only if ryoku-keyring holds Ryoku's published signing key
gpg --batch --with-colons --show-keys /etc/pki/rpm-gpg/RPM-GPG-KEY-ryoku | grep -q '^fpr:*EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3:' || exit 1
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ryoku
# Each user's Ryoku config is laid down at their first login
systemctl --global enable ryoku-bootstrap.service
# Login screen: SDDM with Ryoku's greeter theme
G=/usr/share/ryoku/lockscreen/qylock
if [ -x $G/sddm-host/install-greeter-theme ]; then
  $G/sddm-host/install-greeter-theme $G/themes/clockwork/orbital /usr/share/sddm/themes/ryoku false
fi
test -d /usr/share/sddm/themes/ryoku || exit 1
mkdir -p /usr/share/icons/default
[ -e /usr/share/icons/default/index.theme ] || printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Ice\n' > /usr/share/icons/default/index.theme
systemctl disable plasmalogin.service 2>/dev/null || true
systemctl enable sddm.service
systemctl enable ryoku-greeter-guard.service 2>/dev/null || true
# Keep the FaradayOS boot menu and boot splash (Ryoku's package themes GRUB and Plymouth as its own)
/usr/bin/ryoku-grub-menu purge || true

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
