#!/usr/bin/env bash
# FaradayOS v0.0.1 ISO builder. Run on CachyOS as your normal user (it asks for your sudo password).
set -uo pipefail
VERSION="0.0.1"
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
WORK="${WORK:-$HERE/build}"
OUT="${OUT:-$HERE/out}"
ISO="$OUT/FaradayOSv${VERSION}.iso"
LOG="$HERE/build.log"
# Double-clicked from the file manager? Reopen in a terminal window.
if [[ ! -t 1 && -z "${FARADAY_IN_TERM:-}" ]]; then
  export FARADAY_IN_TERM=1
  for t in konsole alacritty kitty xterm; do
    command -v "$t" >/dev/null || continue
    case $t in
      konsole) exec konsole --hold -e "$0" ;;
      *) exec "$t" -e bash -c '"$0"; echo; read -rp "Press Enter to close"' "$0" ;;
    esac
  done
fi
exec > >(tee "$LOG") 2>&1

c(){ printf '\e[38;5;208m==> %s\e[0m\n' "$*"; }
die(){ printf '\e[31m!! %s\e[0m\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] && die "Run this as your normal user, not root."
command -v pacman >/dev/null || die "This needs CachyOS or Arch Linux."
free_gb=$(df -BG --output=avail "$HERE" | tail -1 | tr -dc 0-9)
(( free_gb >= 45 )) || die "Need at least 45 GB free here (have ${free_gb} GB)."

c "Asking for sudo once (kept alive during the build)"
sudo -v || die "sudo failed"
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

c "Installing build tools"
sudo pacman -S --needed --noconfirm archiso grub git base-devel squashfs-tools libisoburn \
  dosfstools mtools erofs-utils edk2-shell memtest86+ memtest86+-efi syslinux || die "Tool install failed"

c "Preparing work folder: $WORK"
sudo rm -rf "$WORK/work"
rm -rf "$WORK/profile" "$WORK/aur"
mkdir -p "$WORK/localrepo" "$WORK/aur" "$OUT"
cp -r "$HERE/profile" "$WORK/profile"

c "Building AUR packages (failures are skipped; they go in the desktop 'extras' installer)"
BUILT=()
while read -r p; do
  [[ -z $p ]] && continue
  c "  AUR: $p"
  if ls "$WORK/localrepo/$p"-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then BUILT+=("$p"); continue; fi
  ( cd "$WORK/aur" && git clone -q "https://aur.archlinux.org/$p.git" && cd "$p" \
    && PKGDEST="$WORK/localrepo" makepkg -si --noconfirm --needed --skippgpcheck ) && BUILT+=("$p") \
    || printf '\e[33m   skipped %s\e[0m\n' "$p"
done < "$HERE/aur-packages.txt"
rm -f "$WORK/localrepo"/*-debug-*.pkg.tar.zst

if ls "$WORK/localrepo"/*.pkg.tar.zst >/dev/null 2>&1; then
  rm -f "$WORK/localrepo"/faraday.*
  repo-add -q "$WORK/localrepo/faraday.db.tar.zst" "$WORK/localrepo"/*.pkg.tar.zst
  printf '\n[faraday]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$WORK/localrepo" >> "$WORK/profile/pacman.conf"
  for p in "${BUILT[@]}"; do
    case $p in cogl|clutter) ;; *) echo "$p" >> "$WORK/profile/packages.x86_64";; esac
  done
fi

c "Patching mkarchiso (disable Arch keyring timer, like CachyOS does)"
cp /usr/bin/mkarchiso "$WORK/mkarchiso"
sed -i 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' "$WORK/mkarchiso"

c "Building the ISO (20-60 min)"
sudo "$WORK/mkarchiso" -v -w "$WORK/work" -o "$OUT" "$WORK/profile" || die "mkarchiso failed - see $LOG"

built=$(ls -t "$OUT"/FaradayOSv*.iso 2>/dev/null | grep -v "FaradayOSv${VERSION}.iso$" | head -1)
[[ -n $built ]] && sudo mv "$built" "$ISO"
sudo chown "$USER:" "$ISO"
( cd "$OUT" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256" )
sudo rm -rf "$WORK/work"

c "Done!"
ls -lh "$ISO"
echo "Flash it: copy to your Ventoy stick, or:  sudo dd if=\"$ISO\" of=/dev/sdX bs=4M status=progress oflag=sync"
