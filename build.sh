#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
OUT="$ROOT/outputs/WindowAlign.app"
BUILD="$ROOT/build"
mkdir -p "$BUILD/module-cache" "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
CLANG_MODULE_CACHE_PATH="$BUILD/module-cache" swiftc \
  -module-cache-path "$BUILD/module-cache" -O \
  -framework AppKit -framework ApplicationServices -framework Carbon \
  "$ROOT"/Sources/*.swift -o "$OUT/Contents/MacOS/WindowAlign"
cp "$ROOT/Info.plist" "$OUT/Contents/Info.plist"
cp "$ROOT/Resources/WindowAlign.icns" "$OUT/Contents/Resources/WindowAlign.icns"
codesign --force --sign - "$OUT"
plutil -lint "$OUT/Contents/Info.plist"
codesign --verify --verbose=2 "$OUT"
echo "$OUT"
