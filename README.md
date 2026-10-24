# FaradayOS v0.0.1 test ISO

Test build only, separate from `main` (this branch shares no history with it).
GitHub can't store a 6.4 GB file, so the ISO is stored here as 69 pieces of 95 MB.

## Get the ISO as one file
**Linux / macOS**
```
curl -fsSL https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.sh | bash
```
**Windows (PowerShell)**
```
irm https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.ps1 | iex
```
Both download every piece, check each one against `pieces.sha256` (re-downloading any damaged piece), join them into `FaradayOSv0.0.1-test.iso` and check its SHA-256:
`2e9b72ff23ee22ac3724ecfd56b82a911b221e889de119c242c3456b387d1ce8`

Or clone just this branch and join locally:
```
git clone --single-branch -b iso-test https://github.com/FaradayMicrosystems/faradayos faradayos-iso
cd faradayos-iso && cat FaradayOSv0.0.1-test.iso.p* > FaradayOSv0.0.1-test.iso && sha256sum -c FaradayOSv0.0.1-test.iso.sha256
```

## Not included
AUR packages (ALVR, WiVRn, xrizer, OpenComposite, Trayscale, LM Studio, CKAN, Ubuntu/Kali wallpapers): install them from the desktop **Install Faraday extras** icon, or build the full ISO from `main` with `./build.sh`.

Built from main at commit 097df41.
