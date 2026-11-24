# FaradayOS handover

Last updated: 24 Nov 2026 (AEST). For someone taking over FaradayOS. Full technical details: [FARADAYOS.md](FARADAYOS.md).

## 1. Who does what

- **Aurora** (GitHub `FaradayMicrosystems`): owner and core author. Does the art (boot animation, logos, wallpaper), fixes, testing on real hardware and docs by hand. Credit her explicitly in PRs and commits.
- **Claude**: manages git, PRs, CI and releases. Use Aurora's supplied files as-is; do not remake them.
- Aurora's time zone: AEST Queensland (UTC+10, no daylight saving). Give times in AEST.
- Communication: explicit, brief replies. Give a completion ETA before starting any work. Give the reason for each decision.

## 2. Current state (24 Nov 2026)

| | `main` | `experimental/quickshell` |
|---|---|---|
| Version | v0.88 (this docs release) | v0.87 |
| Desktop | KDE Plasma | Ryoku (Quickshell) on niri on TTY2, KDE Plasma on TTY4 |
| Status | Alpha. Stable; latest release on GitHub | Aurora's main focus. Being tested on hardware |
| Last change | Docs (v0.88); last code change v0.80 (Fedora updates in the ISO) | v0.87: Ryoku config copied once at first sign-in |
| Built how | CI on every push, published as a Release | CI artifact `FaradayOS-Quickshell-ISO` or Aurora's local build |

No open PRs at handover.

## 3. Open items (unresolved)

1. **Experimental: slow first boot / about one-minute pause after sign-in (v0.87).** CI shows about 7 s from sign-in to niri, so it is not reproduced. **Waiting on Aurora's fresh-install test** of v0.87. If it still happens, ask her for `journalctl -b --user` and `systemd-analyze blame` from the affected PC.
2. **Experimental not yet pushed to `main`.** Aurora will do this herself after testing. **Never merge experimental into main without her explicit go.** PR #23 (experimental -> main) was closed unmerged.
3. **niri vs Hyprland undecided.** Aurora prefers Hyprland, but Ryoku's Fedora 44 Hyprland packages are broken upstream (`hyprglass` needs `libaquamarine.so.14`; COPR ships `.so.15`). Running niri meanwhile. Run `quickshell-probe.yml` to see whether Hyprland installs again; switch-back steps are in `fedora/quickshell/README.md`.
4. **Red `test (as-is)` / `test (with-display-env)` jobs on experimental are a known false alarm.** `fedora-installer-test.yml` tests main's release ISO with experimental's niri flags. Ignore them; the VM test inside `fedora-iso.yml` is the real one.
5. **Main lags experimental on build tooling.** Main's `build-iso.sh` lacks unattended mode, `--network host` DNS fix and auto-retry; `version-bump-check.yml` is only on experimental. Both arrive when experimental goes to main (or port them in a small PR if asked).
6. **Fonts zip** from Aurora (to become default system fonts) not received yet.
7. **UEFI boot label** still says "Fedora". Ask Aurora before touching NVRAM.
8. **Stale branches** on GitHub (`FaradayOS-Lite`, `fedora-mutable`, `iso-test`, `v0.0.57`-`v0.0.68`, merged `claude/*`). Delete only with Aurora's OK.

## 4. Rules and conventions

- **Base distro: Fedora 44, mutable.** Aurora dislikes locked-down atomic/immutable systems. Do not suggest switching.
- **CachyOS build is deprecated.** Do not fix or develop it. Keep `profile/airootfs/` (shared branding).
- **Version:** format `vX.YY`, in `fedora/VERSION` as `0.88`. **Bump it in every PR**, on every branch, higher than **both** `main` and `experimental/quickshell`. Never three-part (`v0.0.x`). Update README version mentions too.
  - Next free number after this handover: **0.89**.
- **Lean ISO.** Large optional software goes in the add-ons list (`fedora/overlay/usr/share/faraday/addons.list`), never in `%packages`. Ask Aurora before adding anything large to the ISO.
- **Auto-merge.** Claude merges its own PRs once CI passes; do not ask Aurora to merge. If CI fails, fix it. Re-run once for RPM Fusion outages. Exception: never merge experimental into main.
- **PR body:** start with the project attribution lines, credit Aurora, assign `FaradayMicrosystems` and request her review.
- **Branches:** work on `claude/project-thread-*`; PR to `main` or `experimental/quickshell`.

## 5. How to release (main)

1. Branch from `main`. Make the change.
2. Bump `fedora/VERSION` (higher than both branches) and the version text in `README.md` and `fedora/README.md`.
3. Push. `fedora-iso.yml` builds and checks the ISO and runs the VM installer test (about 1-2 hours). Make sure the change touches `fedora/**` or `profile/airootfs/**`, or no build runs (Markdown-only changes do not trigger it).
4. Open the PR to `main`. When CI is green, merge.
5. The merge builds the ISO on `main`; when green, `fedora-release.yml` publishes Release `v<VERSION>` (ISO split into parts, checksums, aria2c command).
6. Check the Release exists with all `.part*` files.

Re-publish a build manually: run `fedora-release.yml` with `run_id`.

## 6. How to release (experimental)

Same steps with `experimental/quickshell` as the base. There is no GitHub Release: the ISO is the `FaradayOS-Quickshell-ISO` artifact (kept 7 days). Aurora usually builds locally:

```
git clone -b experimental/quickshell https://github.com/FaradayMicrosystems/faradayos.git ~/faradayos-quickshell
cd ~/faradayos-quickshell
./fedora/build-iso.sh    # no sudo; asks once; ~40 GB, 30-90 min; ISO in out-fedora/
```

When Aurora says "build the ISO", she usually means this branch. Building main confused her (looked identical). Ask if unsure.

To keep experimental up to date: merge `main` into it. Expect conflicts in `fedora/VERSION`, the `%packages` desktop block and live-session lines of `faradayos.ks`, and the `chmod` line in `apply-branding.sh`.

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
- Experimental edition details: `fedora/quickshell/README.md` on `experimental/quickshell`.
- Ryoku upstream: https://ryoku.dev, https://github.com/Ryoku-dev/ryoku (GPL-3.0).
