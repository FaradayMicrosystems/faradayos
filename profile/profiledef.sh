#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="FaradayOSv0.0.64"
iso_label="FARADAY_001"
iso_publisher="FaradayOS <https://github.com/FaradayMicrosystems>"
iso_application="FaradayOS Live"
iso_version="0.0.64"
install_dir="arch"
buildmodes=('iso')
## GRUB
bootmodes=('bios.syslinux' 'uefi.grub')
## systemd-boot
#bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/share/faraday/rebrand.sh"]="0:0:755"
  ["/usr/local/bin/faraday-extras"]="0:0:755"
  ["/usr/local/bin/faraday-vr-check"]="0:0:755"
  ["/usr/local/bin/faraday-calamares-compat"]="0:0:755"
  ["/usr/local/bin/faraday-prepare-kernels"]="0:0:755"
  ["/etc/skel/Desktop/install-faradayos.desktop"]="0:0:755"
  ["/etc/skel/Desktop/faraday-extras.desktop"]="0:0:755"
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/dmcheck"]="0:0:755"
  ["/usr/local/bin/calamares-online.sh"]="0:0:755"
  ["/usr/local/bin/remove-nvidia"]="0:0:755"
  ["/usr/local/bin/removeun"]="0:0:755"
  ["/usr/local/bin/removeun-online"]="0:0:755"
  ["/usr/local/bin/prepare-live-desktop.sh"]="0:0:755"
  ["/usr/local/bin/nvidia-module-loader"]="0:0:755"
  ["/usr/local/bin/pkexec-wrapper"]="0:0:755"
)
