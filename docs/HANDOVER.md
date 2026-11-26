# FaradayOS handover

Last updated: 26 Nov 2026 (AEST). For someone taking over FaradayOS. Full technical details: [FARADAYOS.md](FARADAYOS.md).

## 1. Who does what

- **Aurora** (GitHub `FaradayMicrosystems`): owner and core author. Does the art (boot animation, logos, wallpaper), fixes, testing on real hardware and docs by hand. Credit her explicitly in PRs and commits.
- **Claude**: manages git, PRs, CI and releases. Use Aurora's supplied files as-is; do not remake them.
- Aurora's time zone: AEST Queensland (UTC+10, no daylight saving). Give times in AEST.
- Communication: explicit, brief replies. Give a completion ETA before starting any work. Give the reason for each decision.

## 2. Current state (26 Nov 2026)

| | `main` |
|---|---|
| Version | v0.90e: two editions, **Performance** and **Workplace**, plus the **FaradayOS Builder** AppImage in every release |
| Desktop | Ryoku (Quickshell) on niri; KDE Plasma as a second session in Performance only; graphical login screen (SDDM, Ryoku greeter) since v0.91e |
| Status | Alpha. Aurora's main focus; being tested on hardware |
| Built how | CI on every push, published as a Release; or Aurora's local build (one command, section 6) |

`experimental/quickshell` is retired (merged as v0.89e on Aurora's go). Do not develop on it.

No open PRs at handover.

## 3. Open items (unresolved)

1. **Experimental: slow first boot / about one-minute pause after sign-in (v0.87).** CI shows about 7 s from sign-in to niri, so it is not reproduced. **Waiting on Aurora's fresh-install test** of v0.87. If it still happens, ask her for `journalctl -b --user` and `systemd-analyze blame` from the affected PC.
2. **Done 25 Nov 2026:** experimental merged into `main` as v0.89e (Aurora's go).
3. **niri vs Hyprland undecided.** Aurora prefers Hyprland, but Ryoku's Fedora 44 Hyprland packages are broken upstream (`hyprglass` needs `libaquamarine.so.14`; COPR ships `.so.15`). Running niri meanwhile. Run `edition-probe.yml` to see whether Hyprland installs again; switch-back steps are in `fedora/quickshell/README.md`.
4. **Red `test (as-is)` / `test (with-display-env)` jobs are a known false alarm** until the first Quickshell Release (v0.89e) exists: `fedora-installer-test.yml` tests the latest Release ISO with the niri flags. Ignore them; the VM test inside `fedora-iso.yml` is the real one.
5. **Done in v0.89e:** main's `build-iso.sh` now has unattended mode, `--network host` and auto-retry; `version-bump-check.yml` checks PRs to `main`.
6. **Fonts zip** from Aurora (to become default system fonts) not received yet.
7. **UEFI boot label** still says "Fedora". Ask Aurora before touching NVRAM.
8. **Stale branches** on GitHub (`FaradayOS-Lite`, `fedora-mutable`, `iso-test`, `v0.0.57`-`v0.0.68`, merged `claude/*`). Delete only with Aurora's OK.

## 4. Rules and conventions

- **Base distro: Fedora 44, mutable.** Aurora dislikes locked-down atomic/immutable systems. Do not suggest switching.
- **CachyOS build is deprecated.** Do not fix or develop it. Keep `profile/airootfs/` (shared branding).
- **Version:** format `vX.YY`, in `fedora/VERSION` as `0.88`. Experimental releases add `e`: `vX.YYe` (e.g. `0.89e`). **Bump it in every PR.** Never three-part (`v0.0.x`). Update README version mentions too.
  - Next free number: **0.92** (or **0.92e** if experimental).
- **Editions.** One kickstart for all editions (`#@if <edition>` blocks); see FARADAYOS.md section 1. New editions: a line in `fedora/editions.list` plus tagged blocks; the Builder app shows it without changes.
- **Lean ISO.** Large optional software goes in the add-ons list (`fedora/overlay/usr/share/faraday/addons.list`), never in `%packages`. Ask Aurora before adding anything large to the ISO.
- **Auto-merge.** Claude merges its own PRs once CI passes; do not ask Aurora to merge. If CI fails, fix it. Re-run once for RPM Fusion outages.
- **PR body:** start with the project attribution lines, credit Aurora, assign `FaradayMicrosystems` and request her review.
- **Branches:** work on `claude/project-thread-*`; PR to `main` only. Experimental work goes to `main` too, with an `e` version (Aurora, 25 Nov 2026), so the build command never changes.

## 5. How to release (main)

1. Branch from `main`. Make the change.
2. Bump `fedora/VERSION` (add `e` for experimental work) and the version text in `README.md` and `fedora/README.md`.
3. Push. `fedora-iso.yml` builds and checks the ISO and runs the VM installer test (about 1-2 hours). Make sure the change touches `fedora/**` or `profile/airootfs/**`, or no build runs (Markdown-only changes do not trigger it).
4. Open the PR to `main`. When CI is green, merge.
5. The merge builds the ISO on `main`; when green, `fedora-release.yml` publishes Release `v<VERSION>` (ISO split into parts, checksums, aria2c command).
6. Check the Release exists with all `.part*` files.

Re-publish a build manually: run `fedora-release.yml` with `run_id`.

## 6. Local build (Aurora's usual way)

Always the same command, for every release (experimental or not):

```
git clone https://github.com/FaradayMicrosystems/faradayos.git ~/faradayos   # first time only
cd ~/faradayos && git pull && ./fedora/build-iso.sh                           # Performance; no sudo; asks once; ~40 GB, 30-90 min; ISO in out-fedora/
cd ~/faradayos && git pull && ./fedora/build-iso.sh workplace                 # Workplace
```

Or the FaradayOS Builder app from the release (two buttons, same result, ISOs in `~/FaradayOS-ISOs`).

Never tell Aurora to clone a different branch or folder.

## 7. Gotchas (learned the hard way)

| Gotcha | What to do |
|---|---|
| Anaconda silently skips kickstart repos named `updates` or `fedora-cisco-openh264` | Keep names `fedora-updates` and `cisco-openh264`. ISOs up to v0.79 had no Fedora updates because of this. |
| `livemedia-creator` without `--isfinal` skips Fedora updates | Keep `--isfinal`. |
| Container rpm macro `/etc/rpm/macros.image-language-conf` makes the ISO English-only; installer crashes | `build-iso.sh` deletes it. Keep that line. |
| `cp -a` copied repo files owned by uid 1001 (CI runner) into the image; installer looped and crashed (v0.72) | Always copy with `--no-preserve=ownership`. `verify-iso.sh` fails on uid > 999. |
| Installer keyboard loop on KDE | Keep the gschema override `90_faradayos-keyboard.gschema.override`. |
| Removing Java removes LibreOffice (with Fedora updates) | Do not `dnf remove java`. |
| Excluding group members in `%packages` fails ("matches only excluded packages") | Remove them in `%post` with `dnf remove`. |
| `akmod-nvidia` starts a background build | Bounded wait, then force `akmods`; build fails if the module is missing. |
| Installer drops live boot args, so nouveau grabs NVIDIA cards | `91-faraday-nvidia.ks` + `nvidia-boot-setup.sh`. Secure Boot must be off. |
| `verify-iso.sh` runs inside `bash -euc '...'` | Never use single quotes in it. |
| Parallel PRs conflict on `fedora/VERSION` and the `chmod` line in `apply-branding.sh` | Merge one at a time; re-bump the version. |
| Markdown-only commits trigger no ISO build | PR shows no checks. Use `workflow_dispatch` or include a `fedora/**` change. |
| New branch pushed at an existing SHA does not trigger CI | Use `workflow_dispatch`. |
| WinBoat via `api.github.com` is rate-limited on CI | Use the release page (`expanded_assets`). |
| Steam "not launching" on first start | It is downloading its runtime. Ask before blaming the build. |
| Claude's sandbox cannot reach Fedora mirrors, download artifacts, or run KVM | All builds and tests run on GitHub Actions; read job logs (the VM test prints logs into them). |
| `fedora-verify.yml` can race a new ISO build on `main` ("ISO not found") | Not a real failure. |
| Experimental: Ryoku `QT_QPA_PLATFORM=wayland;xcb` broke the installer window | `environment.d/99-zz-faradayos.conf` overrides it. |
| Experimental: Ryoku launcher hides `NoDisplay` entries (installer was missing) | `livesys-ryoku` writes a visible "Install FaradayOS" entry. |
| Experimental: `fedora-kde` Anaconda profile hides "Create account"; no login screen means no user | `etc/anaconda/conf.d/90-faradayos-accounts.conf`; `plasma-setup` disabled. |
| Experimental: renaming a window title breaks Ryoku window rules matched on that title | Check Ryoku's `config_rules.go` before rebranding titles. |
| Experimental: niri runs XDG autostart entries (KDE video bridge showed a black window) | Add KDE-only autostarts to `KDE_ONLY_AUTOSTART` in `rebrand-ryoku.py`. |
| Experimental: `ryoku-bootstrap.service` enabled globally collided with the session launcher | Keep it disabled globally (v0.87). |
| Experimental: Ryoku package updates re-theme GRUB/Plymouth | `rebrand-ryoku.py` runs after every dnf transaction and resets them. |

## 8. Recovery notes

- **NVIDIA not loading on an installed PC:** Secure Boot off, then `sudo /usr/share/faraday/nvidia-boot-setup.sh` and reboot.
- **Experimental v0.82 install with no user:** reinstall with v0.83+, or from the live USB mount the installed root (btrfs subvolume `root`), `chroot`, then `useradd -m -G wheel NAME && passwd NAME`.
- **Experimental installer will not start:** open kitty, run `liveinst 2>&1 | tee ~/liveinst.log`.
- **Claude Desktop update:** `sudo /usr/libexec/faraday/addon-claude-desktop`.

## 9. Where things are

- Repo: https://github.com/FaradayMicrosystems/faradayos
- Releases: https://github.com/FaradayMicrosystems/faradayos/releases/latest
- Boot animation source: `dark.zip` (537 frames) in the project files.
- Quickshell edition details: `fedora/quickshell/README.md`.
- Ryoku upstream: https://ryoku.dev, https://github.com/Ryoku-dev/ryoku (GPL-3.0).
