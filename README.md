# FaradayOS

FaradayOS is a gaming- and VR-ready Linux system for work and play, built on **Fedora 44 KDE Plasma**. It is a normal, writable Fedora: install software with `dnf` as usual, nothing is locked down.

Current version: **v0.73**. Versions use the format `v0.<number>` (v0.72, v0.73, ...). Earlier releases named `v0.0.<number>` used the wrong format.

## Download
1. Open the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest) and download every `FaradayOSv0.73.iso.part*` file (about 3.7 GB in total, each part under 2 GB).
   Fastest: `aria2c -Z -x16 -s16 <part URLs>` (the release notes have the full command).
2. Join the parts in the download folder:
   - Linux: `cat FaradayOSv0.73.iso.part* > FaradayOSv0.73.iso`
   - Windows (Command Prompt): `copy /b FaradayOSv0.73.iso.part0 + FaradayOSv0.73.iso.part1 FaradayOSv0.73.iso`
3. Write `FaradayOSv0.73.iso` to a USB stick (8 GB+) with Fedora Media Writer or balenaEtcher.
4. Turn off Secure Boot (the NVIDIA driver is not signed), boot the USB, and open **Install to Hard Drive**.

Every push to `main` builds the ISO on GitHub Actions, checks it, and publishes it as a release.

## What you get
- **Desktop:** KDE Plasma, Firefox, LibreOffice, KDE apps, Papirus icons, floating left panel
- **Gaming:** Steam (Proton), GameMode, gamescope, MangoHud
- **Graphics:** AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, prebuilt in the ISO), hybrid laptops (`switcheroo-control`), full codecs and hardware video decoding
- **Laptops:** touchpad (tap-to-click, disable while typing), fingerprint login (`fprintd`), touchscreen, pen and screen rotation
- **VR, one click:** **Install VR tools** in the app menu adds WiVRn + dashboard, ALVR, xrizer, OpenComposite, adb and, on NVIDIA PCs, the NVENC/CUDA libraries, then installs SteamVR through Steam. Firewall ports, headset USB access and the **VR readiness check** (`faraday-vr-check`) are already in the ISO.
- **Wine and Lutris, one click:** **Install Wine and Lutris** in the app menu
- **FaradayOS look:** animated boot screen, KDE splash, wallpaper, colour scheme (black `#0B0B0B`, orange `#FF7A1A`, yellow `#FFC53D`, jade `#00A86B`), lock and login screens, logo icons. Branding is re-applied after updates.
- After install, the computer starts at the login screen; the live user is removed.

Big optional software ships as one-click installers, not in the ISO, to keep the download small.

## Build it yourself
See [fedora/README.md](fedora/README.md): `./fedora/build-iso.sh` builds the ISO in a Fedora container (podman or docker, about 40 GB free disk, 30 to 90 minutes), and `./fedora/verify-iso.sh` checks it.

## Repository layout
- `fedora/`: the FaradayOS build (kickstart `faradayos.ks`, `VERSION`, build and check scripts, Fedora-only files in `overlay/`)
- `profile/airootfs/`: branding shared with the Fedora build (Plymouth boot animation, KDE global theme `org.faraday.desktop`, colour scheme, wallpaper, icons)
- `assets/`: logo and splash source images
- `.github/workflows/`: ISO build, release publishing, ISO check and size report

## Legacy CachyOS build
FaradayOS started on CachyOS (Arch). That build (`build.sh`, `profile/`, `aur-packages.txt`, `Build-FaradayOS*.desktop`) is no longer developed; FaradayOS moved to Fedora for stability. Its files stay because the Fedora build reuses the branding in `profile/airootfs/`.
