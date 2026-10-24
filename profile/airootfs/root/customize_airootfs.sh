#!/bin/bash
set -x
mkdir -p /etc/issue.d
cp -rT /usr/share/faraday/overlay /
/usr/share/faraday/rebrand.sh
/usr/local/bin/faraday-calamares-compat || echo "WARNING: installer compatibility fix failed"
plymouth-set-default-theme faraday || true
# limine-mkinitcpio-hook diverts kernel install; the live ISO needs them in /boot
for m in /usr/lib/modules/*/; do
  [ -f "$m/vmlinuz" ] && [ -f "$m/pkgbase" ] && install -Dm644 "$m/vmlinuz" "/boot/vmlinuz-$(cat $m/pkgbase)"
done
ls -l /boot
mkinitcpio -P
rm -f /etc/skel/Desktop/.directory
