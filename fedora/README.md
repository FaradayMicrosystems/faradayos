# FaradayOS: Fedora edition (not locked down)

A normal, writable Fedora 44 KDE system. Install software with `dnf` as usual; nothing is read-only.

Included:
- KDE Plasma, Firefox, LibreOffice, KDE apps
- Gaming: Steam, Proton, gamescope, GameMode, MangoHud, Lutris, Wine
- Graphics: AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, built into the ISO), full codecs and hardware video decoding
- FaradayOS branding: boot splash (Plymouth), KDE splash, wallpaper, colour scheme, lock and login screens, fastfetch logo. These come from the same files as the CachyOS build (`profile/airootfs`), so changes there apply to both.

## Build the ISO (on your CachyOS PC)

1. Install podman (once):
   ```
   sudo pacman -S podman
   ```
2. Get this branch:
   ```
   git clone -b fedora-mutable https://github.com/FaradayMicrosystems/faradayos.git faradayos-fedora
   cd faradayos-fedora
   ```
3. Build:
   ```
   ./fedora/build-iso.sh
   ```
   It asks for your sudo password once. Needs about 40 GB free disk space and takes 30 to 90 minutes.
   Result: `out-fedora/FaradayOS-Fedora-44.iso` (+ `.sha256`). Build log: `out-fedora/lmc.log`.

## Test

**In a virtual machine (fastest):** create a VM with 4+ CPUs, 8 GB RAM, 40 GB disk, UEFI firmware. Boot the ISO.
NVIDIA cannot be tested in a VM. Use a USB stick on real hardware for that.

**On real hardware:**
1. Write the ISO to a USB stick (8 GB+) with Fedora Media Writer, balenaEtcher, or:
   ```
   sudo dd if=out-fedora/FaradayOS-Fedora-44.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
   Replace `/dev/sdX` with your USB stick. Check with `lsblk` first: `dd` erases the target.
2. **Turn off Secure Boot** in the BIOS. The NVIDIA driver is not signed, so it will not load with Secure Boot on.
3. Boot the USB. Check:
   - FaradayOS boot splash appears during boot
   - FaradayOS wallpaper, KDE splash and orange colour scheme in the live session
   - `nvidia-smi` (NVIDIA) or `vulkaninfo --summary` (AMD) shows your graphics card
   - Steam opens and a game runs
4. To install to disk: open **Install to Hard Drive** on the desktop.

## Files
- `faradayos.ks`: package list and setup steps (Fedora kickstart)
- `apply-branding.sh`: copies FaradayOS branding into the image
- `overlay/`: Fedora-only files (rebrand script that re-applies branding after updates, login screen wallpaper)
- `build-iso.sh`: builds the ISO in a Fedora container

## Not carried over from the CachyOS build
- VR setup (WiVRn, ALVR, `faraday-vr-check`): these use Arch packages. Can be added later.
- GRUB boot menu image: Fedora hides the boot menu by default, so it is not shown.
- Calamares installer: Fedora uses its own installer (Anaconda).
