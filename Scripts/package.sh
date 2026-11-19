#!/bin/bash
# Build WindowAlign.app, then a drag-to-Applications DMG and a /Applications PKG.
# Requires macOS (hdiutil, pkgbuild, productbuild). Ad-hoc app signing is the default.
#
# Optional, not required:
#   WINDOWALIGN_CODESIGN_IDENTITY    codesign identity for the .app (default: -)
#   WINDOWALIGN_INSTALLER_IDENTITY   productbuild identity for the .pkg (unsigned if unset)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: Scripts/package.sh must run on macOS (needs hdiutil, pkgbuild, and productbuild)." >&2
  exit 1
fi

for tool in hdiutil pkgbuild productbuild plutil codesign ditto zsh; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: missing required tool: $tool" >&2
    exit 1
  fi
done

zsh "$ROOT/build.sh"

APP="$ROOT/outputs/WindowAlign.app"
if [[ ! -d "$APP/Contents/MacOS" ]]; then
  echo "error: build did not produce $APP" >&2
  exit 1
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9A-Za-z._-]+$ ]]; then
  echo "error: unexpected CFBundleShortVersionString: $VERSION" >&2
  exit 1
fi

DMG="$ROOT/outputs/WindowAlign-${VERSION}.dmg"
PKG="$ROOT/outputs/WindowAlign-${VERSION}.pkg"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/windowalign-dmg.XXXXXX")"
PKG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/windowalign-pkgroot.XXXXXX")"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/windowalign-pkgwork.XXXXXX")"
MOUNTPOINT=""
cleanup() {
  if [[ -n "$MOUNTPOINT" ]]; then
    hdiutil detach "$MOUNTPOINT" -quiet || hdiutil detach "$MOUNTPOINT" -force || true
    MOUNTPOINT=""
  fi
  rm -rf "$STAGE" "$PKG_ROOT" "$WORK"
}
trap cleanup EXIT

# ditto keeps the ad-hoc signature; cp can strip the metadata codesign verifies.
ditto "$APP" "$STAGE/WindowAlign.app"
if ! codesign --verify "$STAGE/WindowAlign.app" 2>/dev/null; then
  IDENTITY="${WINDOWALIGN_CODESIGN_IDENTITY:--}"
  if [[ -z "$IDENTITY" ]]; then
    IDENTITY="-"
  fi
  codesign --force --sign "$IDENTITY" "$STAGE/WindowAlign.app"
fi

# Create the Applications symlink inside a mounted image. hdiutil -srcfolder
# follows symlinks and would copy the real /Applications folder into the DMG.
SIZE_KB="$(du -sk "$STAGE/WindowAlign.app" | awk '{print $1}')"
SIZE_MB=$(( SIZE_KB / 1024 + 48 ))
if (( SIZE_MB < 64 )); then
  SIZE_MB=64
fi
TEMP_DMG="$WORK/WindowAlign-rw.dmg"
hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "WindowAlign" -ov "$TEMP_DMG"
ATTACH="$(hdiutil attach "$TEMP_DMG" -nobrowse -noverify -noautoopen)"
MOUNTPOINT="$(printf '%s\n' "$ATTACH" | awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"
if [[ -z "$MOUNTPOINT" || ! -d "$MOUNTPOINT" ]]; then
  echo "error: failed to mount the DMG staging image" >&2
  printf '%s\n' "$ATTACH" >&2
  exit 1
fi
ditto "$STAGE/WindowAlign.app" "$MOUNTPOINT/WindowAlign.app"
ln -s /Applications "$MOUNTPOINT/Applications"
sync
hdiutil detach "$MOUNTPOINT" -quiet
MOUNTPOINT=""
rm -f "$DMG" "${DMG}.dmg"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
if [[ ! -f "$DMG" && -f "${DMG}.dmg" ]]; then
  mv "${DMG}.dmg" "$DMG"
fi

mkdir -p "$PKG_ROOT"
ditto "$STAGE/WindowAlign.app" "$PKG_ROOT/WindowAlign.app"

SCRIPTS="$WORK/scripts"
RESOURCES="$WORK/resources"
mkdir -p "$SCRIPTS" "$RESOURCES"
cp "$ROOT/Scripts/installer/postinstall" "$SCRIPTS/postinstall"
chmod 755 "$SCRIPTS/postinstall"
cp "$ROOT/LICENSE" "$RESOURCES/license.txt"
cp "$ROOT/Scripts/installer/welcome.html" "$RESOURCES/welcome.html"
cp "$ROOT/Scripts/installer/readme.html" "$RESOURCES/readme.html"

cat > "$WORK/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>WindowAlign</title>
    <welcome file="welcome.html" mime-type="text/html"/>
    <readme file="readme.html" mime-type="text/html"/>
    <license file="license.txt"/>
    <options customize="never" require-scripts="false"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="main"/>
    </choices-outline>
    <choice id="main" title="WindowAlign">
        <pkg-ref id="local.windowalign.pkg"/>
    </choice>
    <pkg-ref id="local.windowalign.pkg" version="${VERSION}" onConclusion="None">WindowAlign-component.pkg</pkg-ref>
</installer-gui-script>
EOF

COMPONENT="$WORK/WindowAlign-component.pkg"
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "local.windowalign.pkg" \
  --version "$VERSION" \
  --install-location "/Applications" \
  --scripts "$SCRIPTS" \
  --ownership recommended \
  "$COMPONENT"

if [[ -n "${WINDOWALIGN_INSTALLER_IDENTITY:-}" ]]; then
  productbuild \
    --distribution "$WORK/distribution.xml" \
    --resources "$RESOURCES" \
    --package-path "$WORK" \
    --sign "$WINDOWALIGN_INSTALLER_IDENTITY" \
    "$PKG"
else
  productbuild \
    --distribution "$WORK/distribution.xml" \
    --resources "$RESOURCES" \
    --package-path "$WORK" \
    "$PKG"
fi

if [[ ! -f "$DMG" || ! -f "$PKG" ]]; then
  echo "error: expected installer artifacts were not created" >&2
  exit 1
fi
echo "$DMG"
echo "$PKG"
