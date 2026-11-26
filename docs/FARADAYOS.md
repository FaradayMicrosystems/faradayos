# FaradayOS documentation

Last updated: 25 Nov 2026 (AEST). Covers `main` at v0.89e. Since v0.89e the experimental Quickshell edition lives on `main`.

FaradayOS is a Linux operating system for the workplace that also does gaming and VR, with NVIDIA and AMD graphics support. It is built on **Fedora 44** and is a normal, writable system: software installs with `dnf` as usual. Nothing is locked down (no atomic/immutable image).

**Status: alpha.** v0.76 was the first fully working release (installs, boots and runs on real hardware, NVIDIA confirmed on a real PC).

**Authorship.** Aurora is the core author: art (boot animation, logos, wallpaper), fixes, testing and docs. Claude manages git, pull requests and the CI/release pipelines.

Contents:
1. [Editions and branches](#1-editions-and-branches)
2. [Repository layout](#2-repository-layout)
3. [How an ISO is built](#3-how-an-iso-is-built)
4. [Building locally](#4-building-locally)
5. [CI workflows](#5-ci-workflows)
6. [Versioning](#6-versioning)
7. [Releases and downloads](#7-releases-and-downloads)
8. [Branding: boot splash, GRUB, desktop, installer](#8-branding-boot-splash-grub-desktop-installer)
9. [Graphics: NVIDIA and AMD](#9-graphics-nvidia-and-amd)
10. [Gaming](#10-gaming)
11. [Add-ons installer](#11-add-ons-installer)
12. [VR](#12-vr)
13. [Installer and first boot](#13-installer-and-first-boot)
14. [Experimental Quickshell edition](#14-experimental-quickshell-edition)
15. [Testing and checks](#15-testing-and-checks)
16. [Known issues](#16-known-issues)
17. [Release history](#17-release-history)
18. [Legacy CachyOS build (deprecated)](#18-legacy-cachyos-build-deprecated)

---

## 1. Editions and branches

| Branch | Edition | Desktop | Version | Status |
|---|---|---|---|---|
| `main` | FaradayOS: **Performance** and **Workplace** editions | Ryoku (Quickshell shell) on niri on TTY2; KDE Plasma on TTY4 in Performance only | v0.90e | The only branch to build and release from. Every push builds, checks and publishes both ISOs and the Builder app. |
| `experimental/quickshell` | (retired) | | v0.87 | Merged into `main` as v0.89e (25 Nov 2026, on Aurora's go). Do not develop on it any more. |

Editions (since v0.90e, Aurora 26 Nov 2026), listed in `fedora/editions.list`:
- **performance**: gaming, VR, engineering. Steam, gamescope, MangoHud, GameMode, 32-bit NVIDIA libs, VR groundwork, KDE Plasma on TTY4, Gaming and VR add-ons.
- **workplace**: same base, desktop, drivers, branding, LibreOffice; none of the above. Small GNOME apps (Evince, Loupe, Text Editor, Calculator, File Roller, Simple Scan). The add-ons list is the software catalog (about 80 apps in 7 categories).
- One kickstart: `#@if <edition>` ... `#@end` blocks in `fedora/faradayos.ks` hold what differs; `fedora/edition-ks.sh <edition>` writes the edition's kickstart. Keep shared things outside the blocks.
- ISO names: `FaradayOSv<VERSION>-<edition>.iso`; volume label `FaradayOSv0-90e-<edition>`; `/usr/share/faraday/edition` in the image says which one.

Rules:
- **All work, experimental or not, goes to `main`** (Aurora, 25 Nov 2026), so the build command never changes. Experimental releases get an `e` suffix on the version (see section 6).
- Work branches are `claude/project-thread-*`. Each PR targets `main`.
- Other branches on GitHub (`FaradayOS-Lite`, `fedora-mutable`, `iso-test`, `v0.0.57` to `v0.0.68`, merged `claude/*`) are stale. Do not build from them.

## 2. Repository layout

```
fedora/                      The FaradayOS build (the only maintained build)
  VERSION                    Version number, e.g. 0.88 (no "v")
  faradayos.ks               Kickstart: repos, package list, %post setup steps
  build-iso.sh               Builds the ISO in a Fedora container (podman or docker)
  apply-branding.sh          Copies branding + overlay into the image (owned by root)
  verify-iso.sh              Checks a built ISO (PASS/FAIL per line)
  overlay/                   Fedora-only files copied into the image as-is (/etc, /usr)
  test/live-installer-test.py  Boots the ISO in QEMU and starts the installer
  quickshell/                (experimental branch only) Quickshell edition files
profile/airootfs/            Branding shared with the Fedora build (Plymouth, KDE theme,
                             colours, wallpaper, icons). Rest of profile/ is legacy CachyOS.
assets/                      Logo, splash and wallpaper source images
docs/                        This documentation and HANDOVER.md
.github/workflows/           CI: build, release, verify, size report, installer test
```

Key overlay files (`fedora/overlay/`):

| File | Purpose |
|---|---|
| `usr/share/faraday/rebrand-fedora.sh` | Re-applies FaradayOS identity: os-release, GRUB titles, Plymouth theme, KDE defaults, installer colours |
| `usr/lib/systemd/system/faraday-rebrand.service` | Runs the rebrand at every boot |
| `etc/dnf/libdnf5-plugins/actions.d/faraday-rebrand.actions` | Runs the rebrand after every dnf transaction |
| `usr/share/faraday/grub-titles.sh` + `usr/lib/kernel/install.d/99-faraday-titles.install` | Names every boot entry "FaradayOS" |
| `usr/share/faraday/nvidia-boot-setup.sh` + `usr/share/anaconda/post-scripts/91-faraday-nvidia.ks` | Installed systems boot with the NVIDIA driver, not nouveau |
| `usr/lib/modprobe.d/faraday-nvidia.conf`, `usr/lib/dracut/dracut.conf.d/90-faraday-nvidia.conf` | Blacklist nouveau; nvidia-drm modeset |
| `usr/share/faraday/remove-liveuser.sh` + `faraday-remove-liveuser.service` + `post-scripts/90-faraday-remove-liveuser.ks` | Removes the live user and autologin from installed systems |
| `usr/share/faraday/addons.list`, `usr/bin/faraday-addons`, `usr/libexec/faraday/*` | Add-ons checklist installer |
| `usr/bin/faraday-install-vr`, `faraday-steamvr-setup`, `faraday-vr-check`, `faraday-vr-setup.service` | VR installer and checks |
| `usr/lib/firewalld/services/faradayos-vr.xml`, `usr/lib/udev/rules.d/70-faradayos-vr.rules` | VR firewall ports, headset USB access |
| `usr/share/glib-2.0/schemas/90_faradayos-keyboard.gschema.override` | Installer keyboard default (stops the installer keyboard loop) |
| `usr/share/cockpit/branding/fedora-kde/branding.css` | Installer (Anaconda Web UI) colours |
| `etc/xdg/kcminputrc`, `etc/X11/xorg.conf.d/40-faraday-touchpad.conf` | Touchpad: tap-to-click, disable while typing |

## 3. How an ISO is built

1. `fedora/build-iso.sh` starts a `fedora:44` container (privileged, repo mounted read-only at `/src`).
2. Inside it: install `lorax-lmc-novirt pykickstart policycoreutils`, delete `/etc/rpm/macros.image-language-conf` (else the ISO ships English only and the installer crashes), validate the kickstart with `ksvalidator`.
3. `livemedia-creator --make-iso --no-virt --iso-only --isfinal` builds the live ISO from `fedora/faradayos.ks`. `--isfinal` is required, or Anaconda skips the Fedora updates repo. Live boot args blacklist nouveau.
4. Kickstart `%packages`: Fedora live base + Anaconda, KDE Plasma (`@^kde-desktop-environment @kde-apps @kde-media`), LibreOffice, Firefox, Mesa, `akmod-nvidia`, Steam, gamemode, gamescope, MangoHud, laptop support, RPM Fusion ffmpeg and `mesa-va-drivers-freeworld`, Plymouth.
5. Kickstart `%post`:
   - Temporary DNS for the chroot (restored at the end).
   - `apply-branding.sh` copies branding from `profile/airootfs/` and everything in `fedora/overlay/`, with `--no-preserve=ownership` (files must be owned by root).
   - Builds the NVIDIA kernel module for the ISO's kernel (waits for the background akmods build, then forces one; fails the build if missing).
   - Fingerprint login (authselect `with-fingerprint`), VR firewall service, Avahi.
   - Removes large extras: digiKam, proj-data, LibreOffice Base. **Java stays** (LibreOffice needs it with Fedora updates).
   - Enables live session (`livesys`), rebrand service, live-user removal, Plymouth theme `faraday`.
6. Output: `out-fedora/FaradayOSv<VERSION>.iso` plus `.sha256`. Volume label `FaradayOSv0-88` (dots replaced). Size about 4.1 GB.

Kickstart repos: Fedora, `fedora-updates`, `cisco-openh264`, RPM Fusion free/nonfree (+updates, +steam). **Do not rename them to `updates` or `fedora-cisco-openh264`**: Anaconda silently skips repos with those names (ISOs up to v0.79 had no Fedora updates because of this).

## 4. Building locally

Needs: Linux PC with podman (or docker), about 40 GB free disk, 30 to 90 minutes.

```
sudo pacman -S podman        # CachyOS/Arch, once
sudo dnf install podman      # Fedora, once
```

**Easiest: the FaradayOS Builder app** (since v0.90e, Aurora 26 Nov 2026): download `FaradayOS-Builder-v<VERSION>-x86_64.AppImage` from the release, `chmod +x`, open it, press **Build Performance** or **Build Workplace**. ISOs go to `~/FaradayOS-ISOs`. See section 7a.

**The build command (always the same, every release):**
```
git clone https://github.com/FaradayMicrosystems/faradayos.git ~/faradayos   # first time only
cd ~/faradayos && git pull && ./fedora/build-iso.sh                           # Performance; run WITHOUT sudo
cd ~/faradayos && git pull && ./fedora/build-iso.sh workplace                 # Workplace
./fedora/verify-iso.sh out-fedora/FaradayOSv<VERSION>-<edition>.iso           # optional, every line should say PASS
```

Notes:
- `build-iso.sh` is unattended: asks for sudo once and re-runs itself as root, blocks sleep, uses `--network host` (fixes container DNS failures), retries once on failure (mirror outages), logs to `out-fedora/build-<edition>.log`, and shows a desktop notification when done. `FARADAY_OUT=<folder>` changes the output folder. The build container is named `faradayos-build-<edition>` (the Builder stops it by name).
- Old clone folders (`~/faradayos-quickshell`, `faradayos-fedora`) can be deleted; use `~/faradayos` only.
- Logs: `out-fedora/lmc-<edition>.log` (livemedia-creator), `out-fedora/build-<edition>.log`, and the edition's kickstart `out-fedora/faradayos-<edition>.ks`.
- Aurora prefers local builds: GitHub artifact downloads are too slow for her.

## 5. CI workflows

All in `.github/workflows/`. Builds need Fedora mirrors, so they only run on GitHub Actions (not in Claude's cloud sandbox).

| Workflow | Trigger | What it does |
|---|---|---|
| `fedora-iso.yml` (Build Fedora edition ISO) | Push to `main`, `fedora-mutable`, `claude/**` (and `experimental/**` on the experimental branch) touching `fedora/**` (not `fedora/README.md`, `fedora/test/**`), `profile/airootfs/**` or the workflow; manual | Builds both editions side by side (matrix), prints loaded repos, runs `verify-iso.sh` (edition-aware), uploads ISO artifacts (`FaradayOS-Fedora-ISO` = performance, `FaradayOS-Workplace-ISO`, kept 7 days) and logs, then boots each in QEMU and starts the installer. A failed VM test fails the build, so no broken ISO is released. Takes roughly 1 to 2 hours. |
| `fedora-release.yml` | A green `fedora-iso.yml` run on `main`; manual with `run_id` | Splits both ISOs into 1900 MB parts, writes checksums, builds the Builder AppImage (Ubuntu 22.04 for an older glibc) and publishes GitHub Release `v<VERSION>` with all of them (replaces a release with the same tag). |
| `fedora-verify.yml` | Push to `main`/`fedora-mutable` touching `verify-iso.sh` | Re-checks the newest successful ISO without rebuilding. |
| `fedora-size-report.yml` | Manual (`run_id`), or push to `claude/**` touching it | Lists largest packages and folders in an ISO. |
| `fedora-installer-test.yml` | Manual; push touching `fedora/test/**` | Boots the latest release (or a run's ISO) in QEMU, starts the installer, uploads screenshots/logs. Runs 3 variants. |
| `version-bump-check.yml` | Every PR to `main` | Fails unless `fedora/VERSION` is format `X.YY` or `X.YYe` and higher than the target branch. |
| `edition-probe.yml` | Push to `claude/**` touching the kickstart, editions or `addons.list`; manual | In 2 to 5 minutes: resolves each edition's whole package list, checks every catalog app exists (dnf repoquery, Flathub API), reports whether Ryoku's Hyprland packages install yet. |
| `builder.yml` | Push/PR touching `builder/**`, `builder-helper.sh`, `editions.list` | Builds the Builder AppImage, checks the helper and editions, starts the app on a virtual screen (`--smoke-test`), uploads artifact `FaradayOS-Builder-AppImage`. |

Important CI behaviour:
- Changes only to Markdown/README files do **not** trigger the ISO build (paths filter). A PR then shows no checks.
- RPM Fusion mirror outages sometimes fail the build. Re-run once; that usually fixes it.
- Claude's sandbox cannot download artifacts or run KVM, so the VM test prints journal, crash reports and installer logs into the job log. Read the job log of the installer test step before saying an ISO works.

## 6. Versioning

- Format **`vX.YY`**, e.g. v0.88. Stored in `fedora/VERSION` without the `v` (`0.88`).
- **Experimental releases add `e`**: `vX.YYe`, e.g. v0.89e (`0.89e` in `fedora/VERSION`). Same number line: after v0.89e comes v0.90 or v0.90e. Use `e` whenever the release carries untested/experimental work.
- **Never** use three-part versions (`v0.0.70` was an error; after it came v0.72).
- **Bump the version in every PR.** `version-bump-check.yml` enforces it.
- `VERSION` sets: ISO names `FaradayOSv0.90e-<edition>.iso`, volume label `FaradayOSv0-90e-<edition>`, Builder name `FaradayOS-Builder-v0.90e-x86_64.AppImage`, os-release `PRETTY_NAME="FaradayOS v0.88"`, `IMAGE_VERSION=0.88`, release tag `v0.88`. `VERSION_ID` stays Fedora's `44`, because dnf needs it.
- Also update version mentions in `README.md` and `fedora/README.md`.

## 7. Releases and downloads

1. A PR is merged into `main`.
2. `fedora-iso.yml` builds and checks the ISO on `main`.
3. When green, `fedora-release.yml` publishes Release `v<VERSION>` with `FaradayOSv<VERSION>-<edition>.iso.part0..N` for both editions, their `.sha256`, `SHA256SUMS-parts.txt`, and `FaradayOS-Builder-v<VERSION>-x86_64.AppImage` (+ `.sha256`).

### 7a. FaradayOS Builder app
Aurora (26 Nov 2026): main releases a simple GUI that people download to build FaradayOS. Source `builder/main.go` (Go + Fyne 2.8), packaged by `builder/build-appimage.sh` (appimagetool 1.9.0).
- Holds no build logic: downloads the source tarball of its own version (`refs/tags/v<VERSION>`; dev builds use `main`) to `~/.local/share/faradayos-builder/src/`, reads `fedora/editions.list` (one button per line; a new edition needs no app change), runs `fedora/build-iso.sh <edition>`.
- Checks: x86_64 Linux, source downloaded, podman/docker (offers to install via the helper: pacman/dnf/apt/zypper), pkexec, about 45 GB free in the output folder.
- Sign-in: once per session through pkexec, which starts `fedora/builder-helper.sh` as root. The helper only accepts `build <edition> <folder>`, `install-podman`, `fingerprint`, `stop`, `quit`; output folder must belong to the signed-in user. Closing the app stops a running build. It runs from the downloaded source because root cannot read a user's FUSE-mounted AppImage.
- Fingerprint: optional button (shown when a finger is enrolled) adds `auth sufficient pam_fprintd.so` to `/etc/pam.d/polkit-1` (backup kept), only after the user confirms. No NOPASSWD sudo rules or setuid helpers, by design.
- Checks for a newer release on start and offers a link; never updates itself.
- Local test: `FARADAY_BUILDER_SRC=~/faradayos ./FaradayOS-Builder-*.AppImage` (uses that checkout).

To install:
1. Download every `.part*` file from the [latest release](https://github.com/FaradayMicrosystems/faradayos/releases/latest). Fastest: the `aria2c` command in the release notes.
2. Join: Linux `cat FaradayOSv0.88.iso.part* > FaradayOSv0.88.iso`; Windows `copy /b <part0> + <part1> + ... FaradayOSv0.88.iso`.
3. Optional: `sha256sum -c FaradayOSv0.88.iso.sha256` prints `OK`.
4. Write to a USB stick (8 GB+) with Fedora Media Writer or balenaEtcher.
5. **Turn off Secure Boot** (the NVIDIA driver is not signed), boot the USB, open **Install to Hard Drive**.

Experimental (`e`) versions are released from `main` the same way, e.g. Release `v0.89e`.

## 8. Branding: boot splash, GRUB, desktop, installer

Colours: black `#0B0B0B`, orange `#FF7A1A`, yellow `#FFC53D`, jade `#00A86B`.

**Boot splash (Plymouth).** Aurora's own animation: 537 frames (`frame-000.png` to `frame-536.png`), 30 fps, plays once, black background (PR #9). Theme `faraday` in `profile/airootfs/usr/share/plymouth/themes/faraday/` (`faraday.script`, `faraday.plymouth`). Source: `dark.zip` in the project files. `rebrand-fedora.sh` resets `/etc/plymouth/plymouthd.conf` to `Theme=faraday` at every boot and update. Use Aurora's files as-is; do not remake them.

**KDE splash.** The original FaradayOS KDE splash is restored (PR #6), in the global theme `org.faraday.desktop` (`profile/airootfs/usr/share/plasma/look-and-feel/`).

**Desktop.** Global theme `org.faraday.desktop`, FaradayOS colour scheme, wallpaper, Papirus Dark icons with the FaradayOS logo icon theme, floating left panel, lock and login screen wallpaper/logo, fastfetch logo.

**GRUB.** Only FaradayOS entries are shown (PR #15): "FaradayOS (kernel X)" and "FaradayOS (rescue mode)". `grub-titles.sh` retitles `/boot/loader/entries/*.conf`, deletes stale live-image duplicates, repairs the saved default and sets `GRUB_DISTRIBUTOR="FaradayOS"`. It runs from the kernel-install hook, the rebrand service and the dnf hook. Any new boot-entry source must go through it. Not changed: the firmware (UEFI NVRAM) boot label still says "Fedora"; ask Aurora before touching NVRAM.

**os-release.** `NAME="FaradayOS"`, `LOGO=faradayos`. `ID=fedora` is kept so dnf, RPM Fusion and Fedora tools work.

**Installer colours.** os-release has no `VARIANT_ID`, so Anaconda uses Fedora's generic branding folder; `rebrand-fedora.sh` copies FaradayOS `branding.css` and `logo.png` there (PR #11).

**Branding survives updates** via the boot service and the dnf post-transaction hook.

## 9. Graphics: NVIDIA and AMD

- **AMD and Intel:** Mesa (`mesa-dri-drivers`, `mesa-vulkan-drivers`), hardware video decoding via `mesa-va-drivers-freeworld`.
- **NVIDIA:** RPM Fusion `akmod-nvidia`; the module is prebuilt into the ISO for its kernel. nouveau is blocked three ways: live boot args, `modprobe.d` blacklist, dracut `omit_drivers`. On installed systems `nvidia-boot-setup.sh` (Anaconda post-script) adds the kernel args with `grubby`, sets them in `/etc/default/grub`, builds the module for any other kernel and regenerates the initramfs. Fixed in v0.75 (PR #14), confirmed on Aurora's NVIDIA PC.
- Manual repair on an installed PC: `sudo /usr/share/faraday/nvidia-boot-setup.sh`.
- **Secure Boot must be off** (the module is not signed).
- Hybrid laptops: `switcheroo-control`.
- NVIDIA cannot be tested in a VM. Test on real hardware.

## 10. Gaming

Steam (RPM Fusion, repo stays enabled), Proton, gamescope, GameMode, MangoHud, `steam-devices`, gaming sysctl (`99-faraday-gaming.conf`). Steam needs 32-bit graphics libraries: `xorg-x11-drv-nvidia-libs.i686` must match the 64-bit driver version (checked by `verify-iso.sh`).

Tip: Steam's first launch downloads its runtime and can look like it is not starting. Ask whether it is the first launch before blaming the build.

## 11. Add-ons installer

Large optional software is **not** in the ISO (keeps the download small). After install, open **Install FaradayOS add-ons** (desktop icon or app menu), tick items, click OK.

- It is the software catalog (v0.90e): the installer first asks which categories to look at, then shows one checklist per category.
- List: `fedora/overlay/usr/share/faraday/addons.list`, one line per add-on: `id | type | what | label | check`, grouped under `[Category]` lines. `[Category | performance]` = only in those editions; the ISO build's `%post` removes other editions' categories. Types: `dnf`, `flatpak`, `root` (script in `/usr/libexec/faraday/addon-*`), `script` (runs as the user).
- One password prompt for all dnf/flatpak/root add-ons; already-installed ones are skipped; failures are named; a summary lists OK / SKIPPED / FAILED. Safe to re-run.
- Categories (about 80 apps): Office and productivity; CAD and engineering (FreeCAD and SolveSpace from Flathub: not in Fedora 44); Design, photo and video; Communication; PDF and documents; Development and AI; Remote access, security and system; Gaming and VR (performance only: Heroic, ProtonUp-Qt, CKAN, VR tools). Aurora asked for "top 50 per category"; Claude proposed 10 to 20 vetted apps per category instead (fewer good Linux apps exist, e.g. CAD).
- `edition-probe.yml` checks every catalog app exists in minutes; not on Flathub (Nov 2026): ProjectLibre, OrcaSlicer (`io.github.softfever.OrcaSlicer`), Master PDF Editor, QCAD.
- Every ISO build checks every add-on is downloadable and trial-installs the dnf ones (`dnf --assumeno`).
- **To add an add-on:** add one line to `addons.list`. Never add large software to `%packages`; ask Aurora before adding anything large to the ISO.
- WinBoat's `.rpm` is found from the GitHub release page, not `api.github.com` (rate-limited on CI).

## 12. VR

In the ISO (small): firewall service `faradayos-vr` (WiVRn 9757, ALVR 9943-9944, mDNS 5353), Avahi, headset USB udev rules, `steam-devices`, **VR readiness check** (`faraday-vr-check`, also a login notice), **Set up SteamVR** (`faraday-steamvr-setup`), boot-time `faraday-vr-setup.service`.

Installed on demand by **Install VR tools** (`faraday-install-vr`, also an add-on): WiVRn + dashboard, ALVR (upstream tarball into `/opt/alvr`), xrizer (COPR `@xr-sig/xrizer`), OpenComposite, adb, NVIDIA NVENC/CUDA libraries on NVIDIA PCs, then SteamVR through Steam.

## 13. Installer and first boot

- Installer: Anaconda Web UI, started from **Install to Hard Drive**.
- Installer keyboard: a gschema override sets `[('xkb','us')]`; without it the installer re-set the keyboard forever and froze the session (fixed v0.73).
- All image files must be owned by root. v0.72 had files owned by uid 1001 (from `cp -a`), which broke the installer; `verify-iso.sh` now fails on any file with uid above 999.
- After install the PC starts at the login screen; the live user and autologin are removed.
- Fingerprint login: enrol in System Settings > Users.

## 14. Experimental Quickshell edition

On `main` since v0.89e (formerly branch `experimental/quickshell`). Full details in `fedora/quickshell/README.md`.

- **Desktop:** [Ryoku](https://ryoku.dev) (GPL-3.0, by the Ryoku contributors): a hand-written Quickshell shell. Installed from Ryoku's signed Fedora repo (`repo.ryoku.dev`, key fingerprint `EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3`) plus the `sdegler/hyprland` COPR (limited package list).
- **Compositor: niri for now.** Aurora wants Hyprland ("stick to hyprland", 2026-11-10), but Ryoku's Fedora 44 Hyprland packages are uninstallable upstream (`hyprglass` needs `libaquamarine.so.14`, the COPR ships `.so.15`). Switch back: `ryoku-desktop-niri` -> `ryoku-desktop-hyprland` in the kickstart, `Session=hyprland.desktop` in `livesys-ryoku`, `--compositor Hyprland` in `fedora/test/desktop-args`, and the niri checks in `verify-iso.sh`. `quickshell-probe.yml` shows in minutes whether Hyprland installs again. `tty-session` starts Hyprland by itself once it is installed.
- **One desktop per TTY, no graphical login screen:** TTY2 (Ctrl+Alt+F2) = FaradayOS desktop; TTY4 (Ctrl+Alt+F4) = KDE Plasma. PC starts on TTY2. Files: `tty-session`, `niri-session`, `profile.d/faraday-tty-session.sh`, fish equivalent, `faraday-tty2.service`, `livesys-ryoku`.
- **Installer:** "Install FaradayOS" in the app launcher (live USB only; Fedora's entry is hidden from Ryoku's launcher). The installer asks for the user account (v0.83): `etc/anaconda/conf.d/90-faradayos-accounts.conf` re-shows the page that the `fedora-kde` profile hides, and `plasma-setup` is disabled.
- **Branding over Ryoku:** `rebrand-ryoku.py` swaps visible "Ryoku" names, logos, wallpaper, bar mark, fastfetch; "RYOKU" -> "FARADAYOS", "Ryostore" -> "FaradayOS Store"; keeps Ryoku's GRUB theme, snapshot submenu and Plymouth off. Commands, packages and QML module names stay `ryoku` so updates work. Runs in `%post` and after every dnf transaction; `--check` fails the build if anything is left. Rule: renaming a window title breaks any Ryoku window rule that matches that title (the first-run tour float rule had to be re-added).
- **Kept from main:** boot splash, GRUB names, os-release, NVIDIA, gaming, VR, add-ons, LibreOffice. Default apps: kitty, Nautilus, Firefox, fish, btop.
- **Per-user config:** copied once at first sign-in by Ryoku's session launcher. `ryoku-bootstrap.service` is not enabled globally (it collided with the launcher; fixed v0.87).
- **Keeping up with main:** merge `main` into the branch. Expected conflicts: `fedora/VERSION`, the `%packages` desktop block and live-session lines in `faradayos.ks`, and the `chmod` line in `apply-branding.sh`.

Experimental fixes since branching: v0.81 version-bump CI check; v0.82 unattended local build (+ `--network host` DNS fix, installer in launcher); v0.83 installer asks for the user account, first-run tour floats again; v0.84 merge of main; v0.85 KDE video bridge no longer shows a black window in niri; v0.86 no import-environment warning; v0.87 Ryoku config copied only once at first sign-in.

## 15. Testing and checks

- **`verify-iso.sh`:** mounts the ISO in a Fedora container and prints PASS/FAIL for about 50 checks: name/version/label, Plymouth in image and initramfs, KDE theme/splash/wallpaper/lock/login, icons, installer colours, rebrand hooks, GRUB titles, NVIDIA module and nouveau blocking, Steam and 32-bit libs, codecs, lean ISO, add-on downloads and dependency trial install, VR files and ports, file ownership. Its body runs inside `bash -euc '...'`: **never use single quotes in it**.
- **`fedora/test/live-installer-test.py`:** boots the ISO in QEMU/KVM (8 GB, ~6 minutes), logs in as root on serial, starts the installer like the desktop icon does, checks the desktop survives and the installer stays calm (fails at 300+ keyboard/localisation tasks). Experimental adds flags from `fedora/test/desktop-args` (compositor, shell process, launcher entry, account page). It does **not** do a full install.
- **Real hardware:** required for NVIDIA, touchpad, fingerprint and the full install. Aurora tests on her NVIDIA PC.

## 16. Known issues

- **Experimental: slow first boot / about one-minute pause after sign-in** (v0.87). Not reproduced in CI (about 7 s from sign-in to niri). Waiting on Aurora's fresh-install test.
- **Red `test (as-is)` / `test (with-display-env)` jobs** are a known false alarm while the latest Release is still the KDE-only v0.88: `fedora-installer-test.yml` tests the latest *release* with the niri test flags. Should clear once v0.89e is released. The VM test inside `fedora-iso.yml` is the one that counts.
- **Hyprland unavailable** on Fedora 44 Ryoku packages (upstream soname mismatch); experimental runs niri.
- **UEFI boot label** still says "Fedora".
- **RPM Fusion outages** occasionally fail CI; re-run once.
- **`fedora-verify.yml`** can race a fresh ISO build on `main` and fail with "ISO not found" (it downloads the previous run's ISO). Not a real failure.
- **Fonts:** Aurora may send a fonts zip to become the default system fonts (small, OK in the ISO). Not received yet.

## 17. Release history

| Version | PR | Change |
|---|---|---|
| v0.0.70 | #1, #2 | Fedora 44 edition: mutable KDE, gaming, NVIDIA, VR, touchpad, fingerprint (wrong version format) |
| — | #3 | ISO published as a GitHub Release (split parts) |
| — | #4, #5 | Lean ISO: VR and Wine/Lutris as installers; drop digiKam, GIS data, LibreOffice Base (5.6 GB -> 3.7 GB) |
| — | #6 | Animated boot screen, original KDE splash restored |
| v0.72 | #7, #8, #9 | New numbering; Aurora's 537-frame boot animation |
| v0.73 | #10 | Fix live installer crash (root ownership, keyboard loop, all languages) |
| v0.74 | #11, #12 | Installer colours load; add-ons desktop icon |
| — | #13 | VR install no longer stops after the ALVR download |
| v0.75 | #14 | NVIDIA driver loads on installed systems; Steam 32-bit libs in step |
| v0.76 | #15 | GRUB shows only FaradayOS entries. First fully working release |
| v0.77 | #16 | One checklist add-ons installer |
| v0.78 | #17 | More add-ons; CI trial-installs add-on dependencies |
| v0.79 | #18 | Claude Code and Claude Desktop add-ons |
| v0.80 | #19 | ISO includes Fedora updates (repo rename fix); Java kept for LibreOffice |
| v0.81-v0.87 | #20-#29 | Experimental Quickshell edition (see section 14) |
| v0.88 | #30 | Project documentation and handover file |
| v0.89e | #31 | Experimental Quickshell edition merged into `main`; one build command; `e` suffix for experimental versions |
| v0.90e | this PR | Workplace edition next to Performance; software catalog by category; FaradayOS Builder AppImage in every release |

## 18. Legacy CachyOS build (deprecated)

FaradayOS started on CachyOS (Arch, archiso + Calamares). **It is deprecated: do not build, fix or develop it.** Its files (`build.sh`, `profile/` except `profile/airootfs/` branding, `aur-packages.txt`) remain (its `Build-FaradayOS*.desktop` launchers were removed in v0.90e) only because the Fedora build reuses the branding in `profile/airootfs/`.
