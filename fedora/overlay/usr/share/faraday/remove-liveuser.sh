#!/bin/sh
# FaradayOS: on the installed system, remove the live session user and its automatic login,
# so the computer starts at the login screen with only the user made during install.
# Runs from the installer (--installed) and at every boot (does nothing on the live USB).
[ "$1" = --installed ] || ! grep -qw rd.live.image /proc/cmdline || exit 0
for f in /etc/plasmalogin.conf /etc/plasmalogin.conf.d/*.conf /etc/sddm.conf /etc/sddm.conf.d/*.conf; do
  [ -f "$f" ] && grep -q '^User=liveuser' "$f" || continue
  sed -i '/^\[Autologin\]/,/^\[/{/^User=/d;/^Session=/d;/^Relogin=/d}' "$f"
done
rm -f /etc/sudoers.d/liveuser /etc/systemd/system/getty@tty1.service.d/autologin.conf
if id liveuser >/dev/null 2>&1; then
  pkill -KILL -u liveuser 2>/dev/null
  userdel -r -f liveuser 2>/dev/null || userdel -f liveuser
fi
systemctl disable livesys.service livesys-late.service >/dev/null 2>&1
exit 0
