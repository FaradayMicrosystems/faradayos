#!/bin/sh
# FaradayOS: make the installed system boot with the NVIDIA driver instead of nouveau.
# Runs from the installer (inside the new system) and can be run by hand: sudo /usr/share/faraday/nvidia-boot-setup.sh
ARGS="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau"
# Boot entries for the installed kernels
grubby --update-kernel=ALL --args="$ARGS" || echo "nvidia-boot-setup: grubby failed" >&2
# Defaults for kernels installed later
G=/etc/default/grub
if [ -f $G ] && ! grep -q 'modprobe.blacklist=nouveau' $G; then
  if grep -q '^GRUB_CMDLINE_LINUX=' $G; then
    sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $ARGS\"/" $G
  else
    echo "GRUB_CMDLINE_LINUX=\"$ARGS\"" >> $G
  fi
fi
# NVIDIA kernel module for every installed kernel (built into the ISO for its own kernel; build any others)
for K in $(ls /usr/lib/modules); do
  [ -d /usr/lib/modules/$K/kernel ] || continue
  find /usr/lib/modules/$K -name 'nvidia.ko*' | grep -q . || akmods --force --kernels "$K" || true
done
# Boot images without nouveau (see /usr/lib/dracut/dracut.conf.d/90-faraday-nvidia.conf)
dracut -f --regenerate-all || echo "nvidia-boot-setup: dracut failed" >&2
exit 0
