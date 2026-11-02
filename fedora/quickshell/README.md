# FaradayOS Quickshell edition (experimental)

Branch `experimental/quickshell`. Never merged into `main`.

## What is different from main

- **No KDE Plasma.** The desktop is [Ryoku](https://ryoku.dev) (GPL-3.0): a hand-written
  Quickshell shell running on the Hyprland compositor.
- **Compositor:** Quickshell is only a shell (bar, launcher, panels). It needs a Wayland
  compositor underneath. Ryoku's default is Hyprland, but as of 2026-11-03 Ryoku's Fedora 44
  Hyprland plugins (hyprglass) need libaquamarine.so.14 while the Hyprland COPR has moved to .so.15,
  so they cannot install. Until Ryoku rebuilds them this branch uses **niri**, Ryoku's other
  supported compositor (packaged by Fedora itself). To switch back: `ryoku-desktop-niri` ->
  `ryoku-desktop-hyprland` in the kickstart, `Session=hyprland.desktop` in `livesys-ryoku`,
  `--compositor Hyprland` in `fedora/test/desktop-args`, and the niri checks in `verify-iso.sh`.
  The probe workflow (`quickshell-probe.yml`) shows in 2 minutes whether Hyprland resolves again.
- **Packages:** Ryoku's signed Fedora repo (`repo.ryoku.dev`) plus the `sdegler/hyprland` COPR
  (Ryoku still needs hypridle and hyprpicker from it), limited to the Hyprland packages, as Ryoku's own installer does. Both stay enabled so updates work.
- **Login screen:** SDDM with Ryoku's greeter theme (main uses Plasma Login).
- **Default apps (Ryoku's picks):** kitty terminal, Nautilus files, Firefox, fish, btop.
- **Kept from main:** FaradayOS boot splash, GRUB names, os-release, NVIDIA driver, gaming,
  VR and add-ons installers, LibreOffice, the installer.
- **Per-user config:** `ryoku-bootstrap.service` (enabled for all users) runs
  `ryoku materialize` at each user's first login.

## Files

- `fedora/faradayos.ks`: package list and Ryoku setup in `%post` (search for "Ryoku").
- `fedora/quickshell/overlay/`: repo files, SDDM config, live-session script; copied into the image.
- `fedora/test/desktop-args`: tells the VM installer test which compositor and shell to look for.

## Keeping up with main

Merge `main` into this branch. Expected conflicts: `fedora/VERSION`, the `%packages` desktop
block and the live-session lines in `fedora/faradayos.ks`.
