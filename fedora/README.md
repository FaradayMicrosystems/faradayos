# FaradayOS: Fedora build

Current version: **FaradayOS v0.73** (set in `fedora/VERSION`). ISO file: `FaradayOSv0.73.iso`.

**Version numbering changed:** versions are now `v0.<number>` (for example v0.72, then v0.73). Earlier releases named `v0.0.<number>` (such as v0.0.70) used the wrong format; that was Claude's error. All new releases use the new format.

A normal, writable Fedora 44 KDE system. Install software with `dnf` as usual; nothing is read-only.

Included:
- KDE Plasma, Firefox, LibreOffice, KDE apps
- Gaming: Steam, Proton, gamescope, GameMode, MangoHud
- One-click installers in the app menu (kept out of the ISO so it stays small):
  - **Install VR tools**: WiVRn + dashboard (Quest/Pico over Wi-Fi), ALVR (SteamVR streaming), xrizer + OpenComposite (SteamVR games on WiVRn), adb for wired headsets, NVIDIA video encoding/CUDA libraries on NVIDIA PCs, then installs SteamVR through Steam and gives it realtime priority
  - **Install Wine and Lutris**: Windows apps and non-Steam games
  - Already in the ISO for VR: firewall ports (WiVRn 9757, ALVR 9943-9944, mDNS 5353), Avahi, headset USB access, `steam-devices`, **Set up SteamVR**, **VR readiness check** (`faraday-vr-check`)
- Graphics: AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, built into the ISO), full codecs and hardware video decoding
- Laptops: touchpad (tap-to-click, disable while typing), fingerprint login (fprintd + authselect `with-fingerprint`), touchscreen, pen, screen rotation
- After install: starts at the login screen; the live user is removed
- FaradayOS branding: animated boot screen (Plymouth, frames in `profile/airootfs/usr/share/plymouth/themes/faraday/`), KDE splash, wallpaper, colour scheme, lock and login screens, fastfetch logo. These come from the same files as the CachyOS build (`profile/airootfs`), so changes there apply to both.

## Get the ISO

**Option A: download it (no build needed).** Every push to `main` builds the ISO, checks it and publishes it.
1. Open the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest) and download every `FaradayOSv<version>.iso.part*` file (about 3.7 GB in total, each under 2 GB; downloads can resume). Fastest: the `aria2c` command in the release notes.
2. Join the parts into one ISO, in the download folder:
   - Linux: `cat FaradayOSv0.73.iso.part* > FaradayOSv0.73.iso`
   - Windows (Command Prompt): `copy /b FaradayOSv0.73.iso.part0 + FaradayOSv0.73.iso.part1 FaradayOSv0.73.iso` (the release notes list the exact parts)
3. Optional check: `sha256sum -c FaradayOSv0.73.iso.sha256` prints `OK`.

**Option B: build it yourself (on any Linux PC).**

1. Install podman (once):
   ```
   sudo dnf install podman      # Fedora
   sudo pacman -S podman        # Arch / CachyOS
   ```
2. Get the code:
   ```
   git clone https://github.com/FaradayMicrosystems/faradayos.git faradayos-fedora
   cd faradayos-fedora
   ```
3. Build:
   ```
   ./fedora/build-iso.sh
   ```
   It asks for your sudo password once. Needs about 40 GB free disk space and takes 30 to 90 minutes.
   Result: `out-fedora/FaradayOSv0.73.iso` (+ `.sha256`). Build log: `out-fedora/lmc.log`.

4. Optional: check the ISO (branding, boot splash, wallpaper, NVIDIA module, codecs, Steam):
   ```
   ./fedora/verify-iso.sh
   ```
   Every line should say PASS.

## Test

**In a virtual machine (fastest):** create a VM with 4+ CPUs, 8 GB RAM, 40 GB disk, UEFI firmware. Boot the ISO.
NVIDIA cannot be tested in a VM. Use a USB stick on real hardware for that.

**On real hardware:**
1. Write the ISO to a USB stick (8 GB+) with Fedora Media Writer, balenaEtcher, or:
   ```
   sudo dd if=out-fedora/FaradayOSv0.73.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
   Replace `/dev/sdX` with your USB stick. Check with `lsblk` first: `dd` erases the target.
2. **Turn off Secure Boot** in the BIOS. The NVIDIA driver is not signed, so it will not load with Secure Boot on.
3. Boot the USB. Check:
   - FaradayOS boot animation plays during boot
   - FaradayOS wallpaper, KDE splash and orange colour scheme in the live session
   - `vulkaninfo --summary` shows your graphics card (NVIDIA or AMD)
   - Steam opens and a game runs
4. To install to disk: open **Install to Hard Drive** on the desktop.

## Files
- `faradayos.ks`: package list and setup steps (Fedora kickstart)
- `apply-branding.sh`: copies FaradayOS branding into the image
- `VERSION`: FaradayOS version, used for the ISO name, volume label and os-release
- `overlay/`: Fedora-only files (rebrand script that re-applies branding after updates, login screen wallpaper, VR and Wine installers, firewall service, udev rules)
- `build-iso.sh`: builds the ISO in a Fedora container
- `verify-iso.sh`: checks a built ISO
- Workflows in `.github/workflows/`: `fedora-iso.yml` (build + check), `fedora-release.yml` (publish release parts), `fedora-verify.yml`, `fedora-size-report.yml`

## Not carried over from the CachyOS build
- GRUB boot menu image: Fedora hides the boot menu by default, so it is not shown.
- Calamares installer: Fedora uses its own installer (Anaconda).
