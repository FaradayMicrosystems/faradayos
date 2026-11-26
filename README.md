# FaradayOS

FaradayOS is a gaming- and VR-ready Linux system for work and play, built on **Fedora 44**. Desktop: the FaradayOS (Quickshell) desktop on TTY2, KDE Plasma on TTY4. It is a normal, writable Fedora: install software with `dnf` as usual, nothing is locked down.

Two editions, same base and look:
- **Performance:** gaming, VR and engineering (Steam, VR tools, KDE Plasma on TTY4).
- **Workplace:** lighter, for office, CAD and design work. No gaming, VR or Plasma; a software catalog of about 80 apps by category (office, CAD, design, communication, PDF, development, remote access) installs what you tick.

Current version: **v0.90e** (set in `fedora/VERSION`). Versions use the format `vX.YY`, with an `e` suffix for experimental releases (v0.88, v0.89e, ...). Earlier releases named `v0.0.<number>` used the wrong format.

**Status: alpha.** v0.76 was the first release that works fully out of the box: it installs, boots and runs on real hardware, including NVIDIA graphics (confirmed on a real NVIDIA PC). Some rough edges remain.

## Get FaradayOS
**Easiest: the FaradayOS Builder app.** Download `FaradayOS-Builder-v<version>-x86_64.AppImage` from the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest), make it executable (`chmod +x FaradayOS-Builder-*.AppImage`), open it, and press **Build Performance** or **Build Workplace**. You sign in once (password, or fingerprint if set up); the ISO lands in `~/FaradayOS-ISOs`. Works on any 64-bit Linux PC with podman (the app offers to install it), about 45 GB free and about 1 hour per edition. Source: [`builder/`](builder/).

**Or download a ready ISO** from the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest):
1. Download every `.part` file of ONE edition, e.g. `FaradayOSv0.90e-workplace.iso.part*` (each part under 2 GB). Fastest: `aria2c -Z -x16 -s16 <part URLs>` (the release notes have the full command).
2. Join the parts in the download folder:
   - Linux: `cat FaradayOSv0.90e-workplace.iso.part* > FaradayOSv0.90e-workplace.iso`
   - Windows (Command Prompt): `copy /b FaradayOSv0.90e-workplace.iso.part0 + FaradayOSv0.90e-workplace.iso.part1 FaradayOSv0.90e-workplace.iso`
3. Write the ISO to a USB stick (8 GB+) with Fedora Media Writer or balenaEtcher.
4. Turn off Secure Boot (the NVIDIA driver is not signed), boot the USB, and open **Install to Hard Drive**.

Every push to `main` builds both editions on GitHub Actions, checks them, and publishes them with the Builder app as a release.

## What you get
- **Desktop:** KDE Plasma, Firefox, LibreOffice, KDE apps, Papirus icons, floating left panel
- **Gaming:** Steam (Proton), GameMode, gamescope, MangoHud
- **Graphics:** AMD and Intel (Mesa), NVIDIA (RPM Fusion driver, prebuilt in the ISO), hybrid laptops (`switcheroo-control`), full codecs and hardware video decoding
- **Laptops:** touchpad (tap-to-click, disable while typing), fingerprint login (`fprintd`), touchscreen, pen and screen rotation
- **Add-ons, one checklist:** see [Add-ons](#add-ons) below
- **VR ready:** firewall ports, headset USB access and the **VR readiness check** (`faraday-vr-check`) are in the ISO; the VR apps themselves are an add-on
- **FaradayOS look:** animated boot screen, KDE splash, wallpaper, colour scheme (black `#0B0B0B`, orange `#FF7A1A`, yellow `#FFC53D`, jade `#00A86B`), lock and login screens, logo icons. Branding is re-applied after updates.
- After install, the computer starts at the login screen; the live user is removed.

## Add-ons (software catalog)
Big optional software is not in the ISO, so the download stays small. After installing FaradayOS, open **Install FaradayOS add-ons** (desktop icon or app menu). Pick the categories you want to look at (Office and productivity, CAD and engineering, Design photo and video, Communication, PDF and documents, Development and AI, Remote access security and system, and Gaming and VR in the Performance edition), tick apps in each, and click OK. The ticked add-ons then install one after another in a terminal window:
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

**Adding an add-on:** add one line under its `[Category]` in [`fedora/overlay/usr/share/faraday/addons.list`](fedora/overlay/usr/share/faraday/addons.list). `[Category | performance]` limits a category to some editions. The format is explained at the top of that file. The edition probe workflow checks in minutes that every app exists. Each ISO build checks that every add-on in the list can still be downloaded, and does a trial install of all of them to prove their dependencies resolve.

## Build it yourself
Use the Builder app (above), or the command line, see [fedora/README.md](fedora/README.md):
- `./fedora/build-iso.sh` builds the Performance ISO, `./fedora/build-iso.sh workplace` the Workplace ISO, in a Fedora container (podman or docker, about 40 GB free disk, 30 to 90 minutes). Result: `out-fedora/FaradayOSv<version>-<edition>.iso`.
- `./fedora/verify-iso.sh out-fedora/FaradayOSv<version>-<edition>.iso` checks it.
- Editions are listed in [`fedora/editions.list`](fedora/editions.list); `#@if <edition>` blocks in `fedora/faradayos.ks` hold what differs.

## Repository layout
- `fedora/`: the FaradayOS build (kickstart `faradayos.ks`, `editions.list`, `VERSION`, build and check scripts, Fedora-only files in `overlay/`)
- `builder/`: the FaradayOS Builder app (Go + Fyne, packaged as an AppImage by `build-appimage.sh`)
- `profile/airootfs/`: branding shared with the Fedora build (Plymouth boot animation, KDE global theme `org.faraday.desktop`, colour scheme, wallpaper, icons)
- `assets/`: logo and splash source images
- `.github/workflows/`: ISO build, release publishing, ISO check and size report
- `docs/`: full project documentation ([FARADAYOS.md](docs/FARADAYOS.md)) and the handover file ([HANDOVER.md](docs/HANDOVER.md))

## Legacy CachyOS build
FaradayOS started on CachyOS (Arch). **Do not use it**: that build (`build.sh`, `profile/`, `aur-packages.txt`) is no longer developed (its desktop launchers were removed in v0.90e; use the Builder app); FaradayOS moved to Fedora for stability. Its files stay because the Fedora build reuses the branding in `profile/airootfs/`.
