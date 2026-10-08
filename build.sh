#!/bin/zsh
# Builds Veil with SwiftPM and assembles a signed (ad-hoc) .app bundle in build/.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="Veil"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "▸ Compiling ($CONFIG)…"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

mkdir -p "$BUILD_DIR"
if [[ ! -f "$BUILD_DIR/AppIcon.icns" || Tools/make-icon.swift -nt "$BUILD_DIR/AppIcon.icns" ]]; then
  echo "▸ Rendering app icon…"
  swiftc -O -o "$BUILD_DIR/make-icon" Tools/make-icon.swift
  rm -rf "$BUILD_DIR/AppIcon.iconset"
  "$BUILD_DIR/make-icon" "$BUILD_DIR/AppIcon.iconset" >/dev/null
  iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$BUILD_DIR/AppIcon.icns"
fi

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP" 2>/dev/null

echo "✓ Built $APP"
