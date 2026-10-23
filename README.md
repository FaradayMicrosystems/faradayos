# FaradayOS v0.0.1 test ISO

Test build only. GitHub can't store one file this large (6.4 GB), so it's split into 69 pieces here. The scripts below download them and give you **one ISO**, checked against its SHA-256.

**Linux / macOS**
```
curl -fsSL https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.sh | bash
```
**Windows (PowerShell)**
```
irm https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.ps1 | iex
```
Result: `FaradayOSv0.0.1-test.iso` in the folder you ran it from. SHA-256: `2e9b72ff23ee22ac3724ecfd56b82a911b221e889de119c242c3456b387d1ce8`

Not included in this test build: AUR packages (ALVR, WiVRn, xrizer, OpenComposite, Trayscale, LM Studio, CKAN, Ubuntu/Kali wallpapers). Install them from the desktop **Install Faraday extras** icon.

This branch has no shared history with `main`. To clone the build kit without the ISO: `git clone --single-branch -b main https://github.com/FaradayMicrosystems/faradayos.git`
