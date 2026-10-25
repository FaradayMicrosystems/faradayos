#!/bin/sh
# Re-applies FaradayOS identity after updates overwrite it. Repo/keyring/mirror names are left alone so updates keep working.
cat > /etc/os-release <<OS
NAME="FaradayOS"
PRETTY_NAME="FaradayOS"
ID=arch
ID_LIKE=cachyos
BUILD_ID=rolling
VERSION_ID=0.0.67
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
  grep -rlIZ CachyOS /etc/calamares /usr/share/calamares/modules 2>/dev/null | xargs -0 -r sed -i 's/CachyOS/FaradayOS/g'
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
# Show Ubuntu and Kali wallpapers in KDE's wallpaper picker (they install to GNOME's folders)
_link_walls(){ # $1 = KDE folder name; image folders to link come one per line on stdin
  dest=/usr/share/wallpapers/$1; rm -rf "$dest"
  while IFS= read -r src; do
    [ -d "$src" ] || continue
    find "$src" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \) -print0 |
    while IFS= read -r -d '' f; do
      mkdir -p "$dest"; ln -sf "$f" "$dest/$(basename "$(dirname "$f")")-$(basename "$f")"
    done
  done
  true
}
pacman -Qq ubuntu-wallpapers >/dev/null 2>&1 || rm -rf /usr/share/wallpapers/Ubuntu
pacman -Qq kali-wallpapers >/dev/null 2>&1 || rm -rf /usr/share/wallpapers/Kali
pacman -Qq ubuntu-wallpapers >/dev/null 2>&1 && \
  pacman -Qlq ubuntu-wallpapers | grep -E '^/usr/share/backgrounds/.*[^/]$' | sed 's#/[^/]*$##' | sort -u | _link_walls Ubuntu
pacman -Qq kali-wallpapers >/dev/null 2>&1 && \
  pacman -Qlq kali-wallpapers | grep -iE '\.(jpg|jpeg|png|webp|svg)$' | grep -v '^/usr/share/wallpapers/' | sed 's#/[^/]*$##' | sort -u | _link_walls Kali
true
# GPU-failure screen (cachyos-drm-awaiter): FaradayOS help link and log name
F=/usr/lib/systemd/scripts/drm-failure-handler
[ -f $F ] && sed -i 's#https://wiki.cachyos.org#https://github.com/FaradayMicrosystems/faradayos#g; s#/cachyos-bugreport-\$(date#/faradayos-bugreport-$(date#' $F
true
