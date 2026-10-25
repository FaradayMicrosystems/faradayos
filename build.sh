#!/usr/bin/env bash
# FaradayOS v0.0.68 ISO builder. Run on CachyOS as your normal user (it asks for your sudo password).
#   ./build.sh               build from this folder; asks for your sudo password once
#   ./build.sh --unattended  update to the latest FaradayOS, then build with no further input:
#                            after your password, a temporary passwordless-sudo rule is added
#                            for the build and always removed when it ends, fails or is cancelled
set -uo pipefail
UNATTENDED=0
for a in "$@"; do
  case $a in
    --unattended|-y) UNATTENDED=1 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $a (try --help)"; exit 2 ;;
  esac
done
VERSION="0.0.68"
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
      konsole) exec konsole --hold -e "$0" "$@" ;;
      *) exec "$t" -e bash -c '"$0" "$@"; echo; read -rp "Press Enter to close"' "$0" "$@" ;;
    esac
  done
fi
exec > >(trap '' INT TERM HUP; exec tee "$LOG") 2>&1  # tee ignores Ctrl+C so cleanup messages still show

c(){ printf '\e[38;5;208m==> %s\e[0m\n' "$*"; }
die(){ printf '\e[31m!! %s\e[0m\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] && die "Run this as your normal user, not root."
command -v pacman >/dev/null || die "This needs CachyOS or Arch Linux."

if (( UNATTENDED )) && [[ -z "${FARADAY_UPDATED:-}" ]] && git -C "$HERE" rev-parse --git-dir >/dev/null 2>&1; then
  c "Updating to the latest FaradayOS"
  before=$(sha256sum "$HERE/build.sh")
  git -C "$HERE" pull --ff-only || die "git pull failed (local changes?). Commit or stash them, or run without --unattended."
  if [[ "$(sha256sum "$HERE/build.sh")" != "$before" ]]; then
    c "build.sh was updated; restarting with the new version"
    export FARADAY_UPDATED=1
    exec "$HERE/build.sh" "$@"
  fi
fi
free_gb=$(df -BG --output=avail "$HERE" | tail -1 | tr -dc 0-9)
(( free_gb >= 45 )) || die "Need at least 45 GB free here (have ${free_gb} GB)."

c "Asking for sudo once (kept alive during the build)"
sudo -v || die "sudo failed"
if (( UNATTENDED )); then
  SUDO_RULE=/etc/sudoers.d/zz-faradayos-build  # zz: sudo reads this folder in name order and the last match wins
  _drop_rule(){
    sudo -n rm -f "$SUDO_RULE" 2>/dev/null || sudo rm -f "$SUDO_RULE" 2>/dev/null
    if sudo -n test -e "$SUDO_RULE" 2>/dev/null || [[ -e $SUDO_RULE ]]; then
      printf '\e[31m!! Could not remove %s. Remove it yourself: sudo rm %s\e[0m\n' "$SUDO_RULE" "$SUDO_RULE"
    else printf '\e[38;5;208m==> Removed temporary sudo rule\e[0m\n'; fi
  }
  trap _drop_rule EXIT
  trap 'exit 130' INT TERM HUP
  tmp=$(mktemp); printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$USER" > "$tmp"
  if visudo -cqf "$tmp" 2>/dev/null || sudo visudo -cqf "$tmp"; then
    sudo install -m 440 -o root -g root "$tmp" "$SUDO_RULE" || die "Couldn't add temporary sudo rule"
  else
    rm -f "$tmp"; die "Temporary sudo rule failed validation"
  fi
  rm -f "$tmp"
  c "Unattended: temporary passwordless sudo for $USER until this build ends"
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# pacman allows one package operation at a time and marks it with a lock file. Wait while another
# package manager (updater, software store) really is running; clear the lock only if nothing
# holds it, which means an earlier run was interrupted and left it behind.
wait_pacman_lock(){
  local lck=/var/lib/pacman/db.lck waited=0
  while [[ -e $lck ]]; do
    if sudo fuser -s "$lck" 2>/dev/null || pgrep -x 'pacman|paru|yay|pamac|pamac-daemon|octopi|packagekitd' >/dev/null; then
      (( waited == 0 )) && c "Another package manager is running; waiting for it to finish (up to 15 min)"
      (( waited >= 900 )) && die "Package manager still busy after 15 min. Close it and run again."
      sleep 10; waited=$((waited + 10))
    else
      c "Removing stale pacman lock left by an interrupted run"
      sudo rm -f "$lck"
    fi
  done
}

c "Installing build tools"
wait_pacman_lock
sudo pacman -S --needed --noconfirm archiso grub git base-devel squashfs-tools libisoburn \
  dosfstools mtools erofs-utils edk2-shell memtest86+ memtest86+-efi syslinux || die "Tool install failed"

c "Preparing work folder: $WORK"
sudo rm -rf "$WORK/work"
rm -rf "$WORK/profile" "$WORK/aur"
mkdir -p "$WORK/localrepo" "$WORK/aur" "$OUT"
cp -r "$HERE/profile" "$WORK/profile"
# Build-time files CachyOS's own ISO builder writes (util-iso.sh); the installer reads version-tag
# CachyOS's Welcome app compares version-tag with CachyOS's latest ISO and warns "older version of
# CachyOS ISO" on any mismatch. Use the CachyOS version this build is based on, so a fresh build
# passes and an old one warns as it ages; FaradayOS's own version goes in faradayos-version.
cachy_ver=$(curl -fsS -m 15 https://cachyos.org/versions.json 2>/dev/null | grep -o '"desktopISOVersion"[^,}]*' | grep -o '[0-9]\{6\}' || true)
if [[ -n $cachy_ver ]]; then c "Based on CachyOS ISO version $cachy_ver"
else cachy_ver=$(date +%y%m%d); printf '\e[33m   Could not reach cachyos.org; installer may show a "testing ISO" note\e[0m\n'; fi
echo "$cachy_ver" > "$WORK/profile/airootfs/etc/version-tag"
echo "desktop" > "$WORK/profile/airootfs/etc/edition-tag"
echo "$VERSION" > "$WORK/profile/airootfs/etc/faradayos-version"

c "Building AUR packages (failures are skipped; they go in the desktop 'extras' installer)"
BUILT=()
while read -r p; do
  [[ -z $p ]] && continue
  c "  AUR: $p"
  if ls "$WORK/localrepo/$p"-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then BUILT+=("$p"); continue; fi
  wait_pacman_lock
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
    echo "$p" >> "$WORK/profile/packages.x86_64"
  done
fi

# Online install: the installer's FaradayOS step (faraday-online-setup) installs this package list
# from the repos, and the AUR apps from these copies (newest version of each; localrepo is kept
# between builds and can hold older ones)
INST="$WORK/profile/airootfs/usr/share/faraday/install"
mkdir -p "$INST/aur"
cp "$WORK/profile/packages.x86_64" "$INST/packages.x86_64"
declare -A AUR_FILE=() AUR_VER=()
for f in "$WORK/localrepo"/*.pkg.tar.zst; do
  [[ -e $f ]] || continue
  info=$(bsdtar -xOf "$f" .PKGINFO 2>/dev/null) || continue
  n=$(sed -n 's/^pkgname = //p' <<<"$info"); v=$(sed -n 's/^pkgver = //p' <<<"$info")
  [[ -n $n && -n $v ]] || continue
  if [[ -z ${AUR_VER[$n]:-} ]] || (( $(vercmp "$v" "${AUR_VER[$n]}") > 0 )); then AUR_FILE[$n]=$f; AUR_VER[$n]=$v; fi
done
(( ${#AUR_FILE[@]} )) && cp "${AUR_FILE[@]}" "$INST/aur/"
c "Online install: $(grep -c . "$INST/packages.x86_64") packages listed, ${#AUR_FILE[@]} AUR apps copied to the ISO"

c "Patching mkarchiso (disable Arch keyring timer, like CachyOS does)"
cp /usr/bin/mkarchiso "$WORK/mkarchiso"
sed -i 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' "$WORK/mkarchiso"
# A package hook can leave a process running inside the image (chroot). It keeps /proc or /sys
# mounted there ("umount: .../airootfs/proc: target is busy"), and mkarchiso's cleanup then walks
# into them and fails ("find: .../airootfs/proc/...: Invalid argument"). Before that cleanup (and
# before the image is compressed), stop processes running inside the image and unmount leftovers;
# stop the build if anything stays mounted.
cat > "$WORK/release-chroot.sh" <<'EOF'
_faraday_release_chroot() {
    local dir p root m
    dir="$(realpath -- "${pacstrap_dir}")"
    for p in /proc/[0-9]*; do
        root="$(readlink -- "${p}/root" 2>/dev/null)" || continue
        [[ "${root}" == "${dir}" || "${root}" == "${dir}/"* ]] || continue
        _msg_warning "Stopping leftover process ${p#/proc/} in the image: $(tr '\0' ' ' < "${p}/cmdline" 2>/dev/null)"
        kill -9 "${p#/proc/}" 2>/dev/null || true
    done
    sleep 1
    while read -r m; do
        _msg_warning "Unmounting leftover ${m}"
        umount -R -- "${m}" 2>/dev/null || umount -l -- "${m}" 2>/dev/null || true
    done < <(findmnt -rn -o TARGET | grep -F -- "${dir}/" | sort -r)
    if findmnt -rn -o TARGET | grep -qF -- "${dir}/"; then
        _msg_error "Still mounted inside ${dir}; reboot and build again." 1
    fi
}
EOF
sed -i "/^shopt -s extglob\$/r $WORK/release-chroot.sh" "$WORK/mkarchiso"
sed -i 's/^_cleanup_pacstrap_dir() {$/&\n    _faraday_release_chroot/' "$WORK/mkarchiso"
grep -q '^_faraday_release_chroot() {$' "$WORK/mkarchiso" && grep -q '^    _faraday_release_chroot$' "$WORK/mkarchiso" \
  && bash -O extglob -n "$WORK/mkarchiso" || die "Could not patch mkarchiso (archiso changed?) - send build.log"

c "Building the ISO (20-60 min)"
wait_pacman_lock
sudo "$WORK/mkarchiso" -v -w "$WORK/work" -o "$OUT" "$WORK/profile" || die "mkarchiso failed - see $LOG"

built=$(ls -t "$OUT"/FaradayOSv*.iso 2>/dev/null | grep -v "FaradayOSv${VERSION}.iso$" | head -1)
[[ -n $built ]] && sudo mv "$built" "$ISO"
sudo chown "$USER:" "$ISO"
( cd "$OUT" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256" )
sudo rm -rf "$WORK/work"

# Move the finished ISO and its checksum to the Desktop (built in $OUT first, moved only once complete)
DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n $DESKTOP && $DESKTOP != "$HOME" ]] || DESKTOP="$HOME/Desktop"
mkdir -p "$DESKTOP"
if mv -f "$ISO" "$ISO.sha256" "$DESKTOP/"; then
  ISO="$DESKTOP/$(basename "$ISO")"
  c "Moved the ISO to $DESKTOP"
else
  printf '\e[33m   Could not move the ISO to %s; it is still in %s\e[0m\n' "$DESKTOP" "$OUT"
fi

c "Done!"
ls -lh "$ISO"
echo "Flash it: copy to your Ventoy stick, or:  sudo dd if=\"$ISO\" of=/dev/sdX bs=4M status=progress oflag=sync"
