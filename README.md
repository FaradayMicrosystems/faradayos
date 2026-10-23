# FaradayOS

CachyOS-based gaming distro: KDE Plasma (Wayland), AMD-tuned, live USB + Calamares disk install, FaradayOS branding throughout.

## Build the ISO (on your CachyOS PC)

```fish
git clone https://github.com/FaradayMicrosystems/faradayos.git
cd faradayos
```
Then **double-click `Build-FaradayOS.desktop`** (or `build.sh`) in Dolphin. KDE asks once whether to trust/execute it: say yes.
Or run `./build.sh` in a terminal.

It asks for your sudo password once, needs ~45 GB free and takes 20-60 min. Output:
`out/FaradayOSv0.0.1.iso` + `.sha256`. Log in `build.log`.

## Install
Boot the USB, open the installer, choose **offline install** (copies the live system, so all packages come along).

## Layout
- `profile/` archiso profile (CachyOS live profile + FaradayOS changes)
  - `packages.x86_64` package list
  - `airootfs/` files baked into the system: branding, Plymouth splash, KDE splash, fastfetch dragon, gaming sysctl, Calamares branding
  - `airootfs/root/customize_airootfs.sh` runs inside the image after packages install
- `aur-packages.txt` AUR packages built locally and baked in; failures are skipped and offered via the desktop "Install Faraday extras" icon
- `assets/` logo + splash source images

CachyOS repo, keyring and mirrorlist names are kept so `pacman -Syu` keeps working. A pacman hook re-applies FaradayOS branding after updates.
