#!/bin/bash
# Builds the FaradayOS Builder AppImage: builder/dist/FaradayOS-Builder-v<version>-x86_64.AppImage (+ .sha256)
# Usage: builder/build-appimage.sh [version]   (default: fedora/VERSION)
# Needs: Go, a C compiler, OpenGL/X11/Wayland headers (Ubuntu: libgl1-mesa-dev xorg-dev libwayland-dev
# libxkbcommon-dev desktop-file-utils), curl. Used by .github/workflows/builder.yml and the release workflow.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=${1:-$(tr -d '[:space:]' < ../fedora/VERSION)}
NAME=FaradayOS-Builder-v$VERSION-x86_64.AppImage
# appimagetool: a fixed release, not "continuous", so every build uses the same tool
TOOL_URL=https://github.com/AppImage/appimagetool/releases/download/1.9.0/appimagetool-x86_64.AppImage
rm -rf AppDir dist && mkdir -p AppDir/usr/bin dist

CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o AppDir/usr/bin/faradayos-builder .

cp icon.png AppDir/faradayos-builder.png
ln -s faradayos-builder.png AppDir/.DirIcon
cat > AppDir/faradayos-builder.desktop <<DESKTOP
[Desktop Entry]
Type=Application
Name=FaradayOS Builder
Comment=Build FaradayOS ISOs (Performance or Workplace edition)
Exec=faradayos-builder
Icon=faradayos-builder
Categories=Utility;
Terminal=false
DESKTOP
cat > AppDir/AppRun <<'APPRUN'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
exec "$HERE/usr/bin/faradayos-builder" "$@"
APPRUN
chmod +x AppDir/AppRun

TOOL=${APPIMAGETOOL:-$PWD/.cache/appimagetool}
if [ ! -x "$TOOL" ]; then
  mkdir -p .cache
  curl -fsSL --retry 3 -o "$TOOL" "$TOOL_URL"
  chmod +x "$TOOL"
fi
# No FUSE needed (CI runners and containers have none)
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$TOOL" --no-appstream AppDir "dist/$NAME"
(cd dist && sha256sum "$NAME" > "$NAME.sha256")
ls -l dist
