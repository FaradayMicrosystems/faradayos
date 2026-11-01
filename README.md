# FaradayOS

FaradayOS is a gaming- and VR-ready Linux system for work and play, built on **Fedora 44 KDE Plasma**. It is a normal, writable Fedora: install software with `dnf` as usual, nothing is locked down.

Current version: **v0.79** (set in `fedora/VERSION`). Versions use the format `vX.YY` (v0.77, v0.78, v0.79, ...). Earlier releases named `v0.0.<number>` used the wrong format.

**Status: alpha.** v0.76 was the first release that works fully out of the box: it installs, boots and runs on real hardware, including NVIDIA graphics (confirmed on a real NVIDIA PC). Some rough edges remain.

## Download
1. Open the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest) and download every `FaradayOSv0.79.iso.part*` file (about 3.9 GB in total, each part under 2 GB).
   Fastest: `aria2c -Z -x16 -s16 <part URLs>` (the release notes have the full command).
2. Join the parts in the download folder:
   - Linux: `cat FaradayOSv0.79.iso.part* > FaradayOSv0.79.iso`
   - Windows (Command Prompt): `copy /b FaradayOSv0.79.iso.part0 + FaradayOSv0.79.iso.part1 FaradayOSv0.79.iso`
3. Write `FaradayOSv0.79.iso` to a USB stick (8 GB+) with Fedora Media Writer or balenaEtcher.
4. Turn off Secure Boot (the NVIDIA driver is not signed), boot the USB, and open **Install to Hard Drive**.

Every push to `main` builds the ISO on GitHub Actions, checks it, and publishes it as a release.

## What you get
- **Desktop:** KDE Plasma, Firefox, LibreOffice, KDE apps, Papirus icons, floating left panel
- **Gaming:** Steam (Proton), GameMode, gamescope, MangoHud
- **Graphics:** AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, prebuilt in the ISO), hybrid laptops (`switcheroo-control`), full codecs and hardware video decoding
- **Laptops:** touchpad (tap-to-click, disable while typing), fingerprint login (`fprintd`), touchscreen, pen and screen rotation
- **Add-ons, one checklist:** see [Add-ons](#add-ons) below
- **VR ready:** firewall ports, headset USB access and the **VR readiness check** (`faraday-vr-check`) are in the ISO; the VR apps themselves are an add-on
- **FaradayOS look:** animated boot screen, KDE splash, wallpaper, colour scheme (black `#0B0B0B`, orange `#FF7A1A`, yellow `#FFC53D`, jade `#00A86B`), lock and login screens, logo icons. Branding is re-applied after updates.
- After install, the computer starts at the login screen; the live user is removed.

## Add-ons
Big optional software is not in the ISO, so the download stays small. After installing FaradayOS, open **Install FaradayOS add-ons** (desktop icon or app menu), tick what you want, and click OK. The ticked add-ons then install one after another in a terminal window:
- Add-ons you already have are marked "already installed" and skipped.
- Everything except VR installs after **one** password prompt.
- If an add-on fails, its name is shown, the others still install, and a summary at the end lists each one as OK, SKIPPED or FAILED. Running it again is safe.

| Add-on | What it is | Installed from |
|---|---|---|
| Remmina | Remote desktop (RDP, VNC) | Fedora |
| qBittorrent | Torrent downloads | Fedora |
| KDE Connect | Phone and PC together (files, notifications, clipboard) | Fedora |
| GNOME Disks | Format, check and image disks and USB sticks | Fedora |
| Timeshift | System snapshots: roll back after a bad update | Fedora |
| Fingerprint readers | Drivers (`fprintd`, `libfprint`) and fingerprint login. Already in the ISO. | Fedora |
| Wine and Lutris | Windows apps and non-Steam games | Fedora |
| WinBoat | Windows apps in a small Windows VM, with Podman and FreeRDP 3. Needs virtualization turned on in the BIOS and 4 GB+ RAM. | WinBoat GitHub release |
| CKAN | Mod manager for Kerbal Space Program | CKAN's own repository (updates come with system updates) |
| LM Studio | Run AI language models on this PC (about 500 MB) | lmstudio.ai (AppImage in `/opt/lmstudio`) |
| Claude Code | Anthropic's AI coding assistant for the terminal, plus git, GitHub CLI, Node.js/npm, uv, ripgrep and jq. Needs a paid Claude plan. | Anthropic's official dnf repository (updates come with system updates) |
| Claude Desktop | Anthropic's Claude app. Anthropic's Linux beta is built for Ubuntu/Debian only; FaradayOS verifies Anthropic's signed package and unpacks it. Needs a paid Claude plan. To update: `sudo /usr/libexec/faraday/addon-claude-desktop` | Anthropic's official apt repository |
| Popsicle | Write one ISO to several USB sticks at once | Flathub |
| OnlyOffice | Documents, spreadsheets, slides (good Microsoft Office compatibility) | Flathub |
| Heroic Games Launcher | Epic, GOG and Amazon games | Flathub |
| ProtonUp-Qt | Install Proton-GE and other Proton/Wine versions | Flathub |
| Flatseal | Manage Flathub app permissions | Flathub |
| Discord | Chat and voice | Flathub |
| Telegram | Messaging | Flathub |
| Obsidian | Notes | Flathub |
| TIDAL | Music streaming (community app tidal-hifi) | Flathub |
| VR tools | WiVRn + dashboard, ALVR, xrizer, OpenComposite, adb, NVIDIA video encoding libraries on NVIDIA PCs, then SteamVR through Steam | Fedora, ALVR GitHub release, Steam |

VR tools and Wine and Lutris also have their own entries in the app menu (**Install VR tools**, **Install Wine and Lutris**, **Set up SteamVR**).

**Adding an add-on:** add one line to [`fedora/overlay/usr/share/faraday/addons.list`](fedora/overlay/usr/share/faraday/addons.list). The format is explained at the top of that file. Each ISO build checks that every add-on in the list can still be downloaded, and does a trial install of all of them to prove their dependencies resolve.

## Build it yourself
See [fedora/README.md](fedora/README.md): `./fedora/build-iso.sh` builds the ISO in a Fedora container (podman or docker, about 40 GB free disk, 30 to 90 minutes), and `./fedora/verify-iso.sh` checks it.

## Repository layout
- `fedora/`: the FaradayOS build (kickstart `faradayos.ks`, `VERSION`, build and check scripts, Fedora-only files in `overlay/`)
- `profile/airootfs/`: branding shared with the Fedora build (Plymouth boot animation, KDE global theme `org.faraday.desktop`, colour scheme, wallpaper, icons)
- `assets/`: logo and splash source images
- `.github/workflows/`: ISO build, release publishing, ISO check and size report

## Legacy CachyOS build
FaradayOS started on CachyOS (Arch). **Do not use it**: that build (`build.sh`, `profile/`, `aur-packages.txt`, `Build-FaradayOS*.desktop`) is no longer developed; FaradayOS moved to Fedora for stability. Its files stay because the Fedora build reuses the branding in `profile/airootfs/`.
