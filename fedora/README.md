# FaradayOS: Fedora build

Current version: **FaradayOS v0.90e** (set in `fedora/VERSION`). ISO files: `FaradayOSv0.90e-performance.iso` and `FaradayOSv0.90e-workplace.iso`.

## Editions
Listed in `editions.list` (one line each; the Builder app shows one button per line). `faradayos.ks` is shared: lines between `#@if <edition> ...` and `#@end` are only in those editions, and `edition-ks.sh <edition>` prints the kickstart for one edition. A fix outside those blocks reaches every edition.
- **performance**: everything below (Steam, VR groundwork, KDE Plasma on TTY4, 32-bit NVIDIA libraries for Steam).
- **workplace**: same desktop, drivers, branding and LibreOffice; no Steam, VR, Plasma or 32-bit libraries; adds small GNOME apps (Evince PDF viewer, Loupe images, Text Editor, Calculator, archives, Simple Scan). Its add-ons list has no Gaming and VR category. TTY4 is a plain console.
- New edition: add a line to `editions.list`, tag its packages and setup with `#@if`, add a matrix entry in `.github/workflows/fedora-iso.yml` and `edition-probe.yml`, and add `work`-style checks to `verify-iso.sh`.

**Version numbering changed:** versions are now `vX.YY` (for example v0.88, then v0.89e). Earlier releases named `v0.0.<number>` (such as v0.0.70) used the wrong format; that was Claude's error. All new releases use the new format.

A normal, writable Fedora 44 system: FaradayOS (Quickshell) desktop on TTY2, KDE Plasma on TTY4 (see `fedora/quickshell/README.md`). Install software with `dnf` as usual; nothing is read-only.

Included:
- KDE Plasma, Firefox, LibreOffice, KDE apps
- Gaming: Steam, Proton, gamescope, GameMode, MangoHud
- Add-ons (kept out of the ISO so it stays small): **Install FaradayOS add-ons** on the desktop asks which categories to look at, shows a checklist per category and installs the ticked ones in one go, skipping what is already installed. The list is `overlay/usr/share/faraday/addons.list` (one line per add-on under `[Category]` lines; `[Category | performance]` = only in those editions, the ISO build removes the rest); see the [main README](../README.md#add-ons-software-catalog) for what is in it. VR tools and Wine and Lutris also have their own app menu entries.
  - Already in the ISO for VR: firewall ports (WiVRn 9757, ALVR 9943-9944, mDNS 5353), Avahi, headset USB access, `steam-devices`, **Set up SteamVR**, **VR readiness check** (`faraday-vr-check`)
- Graphics: AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, built into the ISO), full codecs and hardware video decoding
- Laptops: touchpad (tap-to-click, disable while typing), fingerprint login (fprintd + authselect `with-fingerprint`), touchscreen, pen, screen rotation
- After install: starts at the login screen; the live user is removed
- FaradayOS branding: animated boot screen (Plymouth, frames in `profile/airootfs/usr/share/plymouth/themes/faraday/`), KDE splash, wallpaper, colour scheme, lock and login screens, fastfetch logo. These come from the same files as the CachyOS build (`profile/airootfs`), so changes there apply to both.

## Get the ISO

**Option A: download it (no build needed).** Every push to `main` builds the ISO, checks it and publishes it.
1. Open the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest) and download every `FaradayOSv<version>-<edition>.iso.part*` file of ONE edition (each under 2 GB; downloads can resume). Fastest: the `aria2c` command in the release notes.
2. Join the parts into one ISO, in the download folder:
   - Linux: `cat FaradayOSv0.90e-workplace.iso.part* > FaradayOSv0.90e-workplace.iso`
   - Windows (Command Prompt): `copy /b FaradayOSv0.90e-workplace.iso.part0 + FaradayOSv0.90e-workplace.iso.part1 FaradayOSv0.90e-workplace.iso` (the release notes list the exact parts)
3. Optional check: `sha256sum -c FaradayOSv0.90e-workplace.iso.sha256` prints `OK`.

**Option B: the FaradayOS Builder app.** Download `FaradayOS-Builder-v<version>-x86_64.AppImage` from the release, `chmod +x` it, open it, press **Build Performance** or **Build Workplace**. It downloads the source of its own version, checks podman and free space, asks you to sign in once (pkexec: password, or fingerprint after you turn that on in the app), and runs `build-iso.sh` through `builder-helper.sh`. ISOs go to `~/FaradayOS-ISOs` (changeable). Source: `../builder/`. To test the app against a local checkout: `FARADAY_BUILDER_SRC=~/faradayos ./FaradayOS-Builder-*.AppImage`.

**Option C: the command line (on any Linux PC).**

1. Install podman (once):
   ```
   sudo dnf install podman      # Fedora
   sudo pacman -S podman        # Arch / CachyOS
   ```
2. Get the code (first time only):
   ```
   git clone https://github.com/FaradayMicrosystems/faradayos.git ~/faradayos
   ```
3. Build (the same command every time, run WITHOUT sudo):
   ```
   cd ~/faradayos && git pull && ./fedora/build-iso.sh              # Performance edition
   cd ~/faradayos && git pull && ./fedora/build-iso.sh workplace    # Workplace edition
   ```
   It asks for your sudo password once at the start, then runs unattended: it keeps the PC awake, retries once if a mirror fails, logs to `out-fedora/build-<edition>.log` and shows a notification when done. Needs about 40 GB free disk space and takes 30 to 90 minutes.
   Result: `out-fedora/FaradayOSv0.90e-<edition>.iso` (+ `.sha256`). Build log: `out-fedora/lmc-<edition>.log`. `FARADAY_OUT=<folder>` writes somewhere else.

4. Optional: check the ISO (branding, boot splash, wallpaper, NVIDIA module, codecs, Steam):
   ```
   ./fedora/verify-iso.sh out-fedora/FaradayOSv0.90e-workplace.iso    # no argument = the performance ISO
   ```
   Every line should say PASS.

## Test

**In a virtual machine (fastest):** create a VM with 4+ CPUs, 8 GB RAM, 40 GB disk, UEFI firmware. Boot the ISO.
NVIDIA cannot be tested in a VM. Use a USB stick on real hardware for that.

**On real hardware:**
1. Write the ISO to a USB stick (8 GB+) with Fedora Media Writer, balenaEtcher, or:
   ```
   sudo dd if=out-fedora/FaradayOSv0.90e-performance.iso of=/dev/sdX bs=4M status=progress oflag=sync
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
- `faradayos.ks`: package list and setup steps (Fedora kickstart, all editions; `#@if` blocks per edition)
- `editions.list`, `edition-ks.sh`: the editions, and the kickstart for one edition
- `builder-helper.sh`: the root part of the Builder app (only accepts build, install-podman, fingerprint, stop)
- `apply-branding.sh`: copies FaradayOS branding into the image
- `VERSION`: FaradayOS version, used for the ISO name, volume label and os-release
- `overlay/`: Fedora-only files (rebrand script that re-applies branding after updates, boot menu hook that names every GRUB entry FaradayOS, login screen wallpaper, add-ons list and installers, VR and Wine installers, firewall service, udev rules)
- `build-iso.sh [edition]`: builds an ISO in a Fedora container
- `verify-iso.sh`: checks a built ISO
- Workflows in `.github/workflows/`: `fedora-iso.yml` (build + check, both editions side by side), `fedora-release.yml` (publish release parts of both editions + the Builder AppImage), `edition-probe.yml` (package lists and catalog apps in minutes), `builder.yml` (Builder AppImage), `fedora-verify.yml`, `fedora-size-report.yml`

## Not carried over from the CachyOS build
- GRUB boot menu image: Fedora hides the boot menu by default, so it is not shown.
- Calamares installer: Fedora uses its own installer (Anaconda).
