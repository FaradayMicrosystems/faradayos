#!/bin/sh
# Re-applies FaradayOS identity after updates overwrite it. Repo/keyring/mirror names are left alone so updates keep working.
cat > /etc/os-release <<OS
NAME="FaradayOS"
PRETTY_NAME="FaradayOS"
ID=arch
ID_LIKE=cachyos
BUILD_ID=rolling
VERSION_ID=0.0.1
ANSI_COLOR="38;5;208"
HOME_URL="https://faradayos.local"
LOGO=faradayos
OS
ln -sf /etc/os-release /usr/lib/os-release 2>/dev/null || true
echo "FaradayOS" > /etc/issue.d/00-faraday.issue 2>/dev/null || true
# Limine boot menu titles
for f in /boot/limine.conf /boot/limine/limine.conf /etc/default/limine; do
  [ -f "$f" ] && sed -i 's/CachyOS/FaradayOS/g; s/Cachy/Faraday/g' "$f"
done
# Plymouth
[ -d /usr/share/plymouth/themes/cachyos-bootanimation ] && \
  sed -i 's/CachyOS/FaradayOS/g' /usr/share/plymouth/themes/*/*.plymouth 2>/dev/null
true
# keep FaradayOS boot splash after plymouth/cachyos theme updates
mkdir -p /etc/plymouth && printf '[Daemon]\nTheme=faraday\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
# Calamares installer branding
B=/usr/share/calamares/branding
if [ -d $B ]; then
  src=$(ls -d $B/* 2>/dev/null | grep -v /faraday$ | head -1)
  [ -n "$src" ] && cp -n "$src"/*.qml "$src"/*.js $B/faraday/ 2>/dev/null
  [ -n "$src" ] && [ -d "$src/lang" ] && cp -rn "$src/lang" $B/faraday/
  sed -i 's/^branding:.*/branding: faraday/' /etc/calamares/settings*.conf /usr/share/calamares/settings*.conf 2>/dev/null
  grep -rlI CachyOS /etc/calamares /usr/share/calamares/modules 2>/dev/null | xargs -r sed -i 's/CachyOS/FaradayOS/g'
fi
true
mkdir -p /etc/plymouth && printf '[Daemon]\nTheme=faraday\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
# keep FaradayOS theme defaults after plasma-login-manager updates
T=/usr/share/faraday/theme
if [ -d $T ]; then
  install -Dm644 $T/kdeglobals /etc/xdg/kdeglobals
  install -Dm644 $T/kdeglobals /etc/skel/.config/kdeglobals
  install -Dm644 $T/kscreenlockerrc /etc/xdg/kscreenlockerrc
  grep -q '^\[Greeter\]\[Wallpaper\]' /etc/plasmalogin.conf 2>/dev/null || \
    printf '\n[Greeter][Wallpaper][org.kde.image][General]\nImage=file:///usr/share/wallpapers/FaradayOS/contents/images/3260x1838.png\n' >> /etc/plasmalogin.conf
  grep -q '^Theme=org.faraday.desktop' /etc/skel/.config/ksplashrc 2>/dev/null || \
    printf '[KSplash]\nEngine=KSplashQML\nTheme=org.faraday.desktop\n' > /etc/skel/.config/ksplashrc
fi
true
