# FaradayOS (Fedora edition): normal, writable Fedora KDE system.
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
# xrizer (OpenVR games on WiVRn), from the Fedora XR SIG
repo --name=copr-xr-sig-xrizer --baseurl=https://download.copr.fedorainfracloud.org/results/@xr-sig/xrizer/fedora-$releasever-$basearch/

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

# Desktop: KDE Plasma and everyday work apps
@^kde-desktop-environment
@kde-apps
@kde-media
@libreoffice
firefox
fastfetch
# Papirus icons (desktop layout is in the FaradayOS global theme)
papirus-icon-theme

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
xorg-x11-drv-nvidia-cuda
switcheroo-control

# Gaming
steam
gamemode
gamescope
mangohud
lutris
wine

# VR: WiVRn (Quest/Pico over Wi-Fi, no SteamVR needed), OpenVR-to-OpenXR layers, headset USB access.
# ALVR is downloaded in %post; SteamVR comes from Steam ("Set up SteamVR" in the app menu).
wivrn
wivrn-dashboard
xrizer
opencomposite
steam-devices
android-tools
avahi
nss-mdns
libcap
libva-utils
xorg-x11-drv-nvidia-cuda-libs

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

# VR: ALVR streamer (MIT licence, upstream release; works with SteamVR on AMD and NVIDIA)
mkdir -p /opt/alvr
curl -fL --retry 5 --retry-delay 10 -o /tmp/alvr.tar.gz \
  https://github.com/alvr-org/ALVR/releases/latest/download/alvr_streamer_linux.tar.gz
tar -xzf /tmp/alvr.tar.gz -C /opt/alvr --strip-components=1
rm -f /tmp/alvr.tar.gz
test -x /opt/alvr/bin/alvr_dashboard
ln -sf /opt/alvr/bin/alvr_dashboard /usr/bin/alvr_dashboard
I=$(find /opt/alvr/share/icons -name 'alvr*.png' 2>/dev/null | sort -V | tail -1)
[ -n "$I" ] && install -Dm644 "$I" /usr/share/icons/hicolor/256x256/apps/alvr.png
# VR: open WiVRn/ALVR/mDNS ports, run the boot-time VR setup, let headsets find this PC
firewall-offline-cmd --add-service=faradayos-vr
Z=$(firewall-offline-cmd --get-default-zone)
[ "$Z" = FedoraWorkstation ] || firewall-offline-cmd --zone=FedoraWorkstation --add-service=faradayos-vr || true
systemctl enable avahi-daemon.service faraday-vr-setup.service

# Live session (from Fedora's KDE live kickstart)
systemctl enable livesys.service livesys-late.service
echo 'livesys_session="kde"' > /etc/sysconfig/livesys

# FaradayOS branding stays after updates
systemctl enable faraday-rebrand.service
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
