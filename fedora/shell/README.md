# FaradayOS Terminal Shell (branch `shell/terminal`)

This branch layers the custom FaradayOS Terminal shell on top of `main`.

- `overlay/`: shell files (themes, plasmoids, decorations). Copied into the image after `fedora/overlay/` by `apply-branding.sh`.
- `DESIGN.md`: the design doc (visual language, components, roadmap).

Rules: keep shell files inside `fedora/shell/` so merging `main` stays conflict-free. Builds from this branch never publish a Release (the release workflow runs only for `main`).
