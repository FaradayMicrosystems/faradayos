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
Boot the USB and open the installer. It copies the live system, so every FaradayOS package and setting comes along. An **Optional apps** page offers the big apps that aren't on the ISO (LibreOffice, GIMP, Krita, Darktable, FreeCAD); they're ticked by default and downloaded during install. With no internet they're skipped and the install still completes. Installer overrides live in `profile/airootfs/usr/share/faraday/calamares/` and are applied by the launcher after it updates the installer.

## Layout
- `profile/` archiso profile (CachyOS live profile + FaradayOS changes)
  - `packages.x86_64` package list
  - `airootfs/` files baked into the system: branding, Plymouth splash, KDE splash, fastfetch dragon, gaming sysctl, Calamares branding
  - `airootfs/root/customize_airootfs.sh` runs inside the image after packages install
- `aur-packages.txt` AUR packages built locally and baked in; failures are skipped and offered via the desktop "Install Faraday extras" icon
- `profile/airootfs/usr/local/bin/faraday-vr-check` VR readiness check (Steam, SteamVR, WiVRn, ALVR, AMD Vulkan, firewall). Runs at boot (`--fix-system`: opens WiVRn/ALVR ports, gives SteamVR's compositor realtime priority) and at login (pops up only if something needs attention). Run `faraday-vr-check` any time.
- Theme: `org.faraday.desktop` global theme, `FaradayOS` colour scheme (black `#0B0B0B`, orange `#FF7A1A`, yellow `#FFC53D`, jade `#00A86B`), `FaradayOS` wallpaper (desktop, lock and login screens), Plymouth + KDE splash with the Faraday Microsystems logo. `rebrand.sh` re-applies the defaults after updates.
- Extra wallpapers: Ubuntu (`ubuntu-wallpapers`) and Kali (`kali-wallpapers`) from the AUR. They install to GNOME folders, so `rebrand.sh` links them into `/usr/share/wallpapers/Ubuntu` and `/Kali` for the KDE wallpaper picker, and refreshes the links after updates.
- `assets/` logo + splash source images

CachyOS repo, keyring and mirrorlist names are kept so `pacman -Syu` keeps working. A pacman hook re-applies FaradayOS branding after updates.

## VR
Steam, WiVRn (server + dashboard), ALVR and xrizer/OpenComposite are preinstalled. SteamVR itself is installed from inside Steam (it needs your Steam account): open Steam, install **SteamVR**, then reboot once so FaradayOS can grant it realtime priority.
