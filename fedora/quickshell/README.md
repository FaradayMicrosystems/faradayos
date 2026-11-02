# FaradayOS Quickshell edition (experimental)

Branch `experimental/quickshell`. Never merged into `main`.

## What is different from main

- **No KDE Plasma.** The desktop is [Ryoku](https://ryoku.dev) (GPL-3.0): a hand-written
  Quickshell shell running on the Hyprland compositor.
- **Why Hyprland:** Quickshell is only a shell (bar, launcher, panels). It needs a Wayland
  compositor underneath. Ryoku's look (blur, animations, its Hyprland plugins) is built for
  Hyprland, and Ryoku's Fedora packages are tested on it. niri is Ryoku's other option.
- **Packages:** Ryoku's signed Fedora repo (`repo.ryoku.dev`) plus the `sdegler/hyprland` COPR,
  limited to the Hyprland packages, as Ryoku's own installer does. Both stay enabled so updates work.
- **Login screen:** SDDM with Ryoku's greeter theme (main uses Plasma Login).
- **Default apps (Ryoku's picks):** kitty terminal, Nautilus files, Firefox, fish, btop.
- **Kept from main:** FaradayOS boot splash, GRUB names, os-release, NVIDIA driver, gaming,
  VR and add-ons installers, LibreOffice, the installer.
- **Per-user config:** `ryoku-bootstrap.service` (enabled for all users) runs
  `ryoku materialize` at each user's first login.

## Files

- `fedora/faradayos.ks`: package list and Ryoku setup in `%post` (search for "Ryoku").
- `fedora/quickshell/overlay/`: repo files, SDDM config, live-session script; copied into the image.
- `fedora/test/desktop-args`: tells the VM installer test to look for Hyprland and Quickshell.

## Keeping up with main

Merge `main` into this branch. Expected conflicts: `fedora/VERSION`, the `%packages` desktop
block and the live-session lines in `fedora/faradayos.ks`.
