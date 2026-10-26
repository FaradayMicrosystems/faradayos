#!/bin/sh
# Re-applies FaradayOS identity on Fedora after updates overwrite it.
# ID=fedora is kept so dnf, RPM Fusion and Fedora tools keep working.
O=/usr/lib/os-release
if [ -f $O ]; then
  sed -i 's/^NAME=.*/NAME="FaradayOS"/; s/^PRETTY_NAME=.*/PRETTY_NAME="FaradayOS"/; s/^LOGO=.*/LOGO=faradayos/; s/^ANSI_COLOR=.*/ANSI_COLOR="38;5;208"/' $O
  grep -q '^LOGO=' $O || echo 'LOGO=faradayos' >> $O
fi
# Boot splash
mkdir -p /etc/plymouth && printf '[Daemon]\nTheme=faraday\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
# KDE theme, lock screen and splash defaults
T=/usr/share/faraday/theme
if [ -d $T ]; then
  install -Dm644 $T/kdeglobals /etc/xdg/kdeglobals
  install -Dm644 $T/kdeglobals /etc/skel/.config/kdeglobals
  install -Dm644 $T/kscreenlockerrc /etc/xdg/kscreenlockerrc
  grep -q '^Theme=org.faraday.desktop' /etc/skel/.config/ksplashrc 2>/dev/null || \
    printf '[KSplash]\nEngine=KSplashQML\nTheme=org.faraday.desktop\n' > /etc/skel/.config/ksplashrc
fi
true
