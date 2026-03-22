#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Peak — build script
#
# Produces a code-signed Peak.app bundle using Swift Package Manager.
# No Xcode IDE required — only Xcode Command Line Tools (or Xcode).
#
# Usage:
#   ./scripts/build.sh                     # ad-hoc signed (dev)
#   SIGN_IDENTITY="Developer ID Application: You (TEAMID)" ./scripts/build.sh
#   VERSION=1.2.0 ./scripts/build.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="Peak"
BUNDLE_ID="com.peak.app"
VERSION="${VERSION:-1.0.0}"
MIN_MACOS="13.0"

BUILD_ROOT=".build"
STAGING="$BUILD_ROOT/staging"
APP_BUNDLE="$STAGING/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Building Peak $VERSION           ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  App name   : $APP_NAME"
echo "  Bundle ID  : $BUNDLE_ID"
echo "  macOS min  : $MIN_MACOS+"
echo "  Signing    : ${SIGN_IDENTITY:0:40}"
echo ""

# ── Step 1: Compile ──────────────────────────────────────────────────────────
ARCH=$(uname -m)
echo "▸ Compiling for $ARCH…"
swift build -c release --arch "$ARCH"
echo ""

BIN=".build/${ARCH}-apple-macosx/release/$APP_NAME"

if [ ! -f "$BIN" ]; then
    echo "❌  Could not find compiled binary at $BIN"
    exit 1
fi

# ── Step 2: Assemble .app bundle ─────────────────────────────────────────────
echo "▸ Assembling $APP_NAME.app…"

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BIN" "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"

echo "  Binary arch: $(lipo -archs "$CONTENTS/MacOS/$APP_NAME")"

# Info.plist (inject real version number)
sed "s/1\.0\.0/$VERSION/g" "Peak/App/Info.plist" > "$CONTENTS/Info.plist"

# ── Step 3: App icon ─────────────────────────────────────────────────────────
echo "▸ Generating app icon…"

# Generate icon PNGs
if command -v swift &>/dev/null && [ -f scripts/generate_icon.swift ]; then
    swift scripts/generate_icon.swift 2>/dev/null || echo "  (icon generation skipped)"
fi

# Build .icns from PNGs
ICONSET_DIR="/tmp/Peak.iconset"
ASSETS_DIR="Peak/Assets.xcassets/AppIcon.appiconset"
if ls "$ASSETS_DIR"/icon_*.png &>/dev/null; then
    rm -rf "$ICONSET_DIR" && mkdir -p "$ICONSET_DIR"
    for f in icon_16x16.png icon_16x16@2x.png icon_32x32.png icon_32x32@2x.png \
             icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png \
             icon_512x512.png icon_512x512@2x.png; do
        [ -f "$ASSETS_DIR/$f" ] && cp "$ASSETS_DIR/$f" "$ICONSET_DIR/$f"
    done
    iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS/Resources/AppIcon.icns" 2>/dev/null \
        && echo "  AppIcon.icns created" \
        || echo "  (iconutil failed — using default icon)"
    rm -rf "$ICONSET_DIR"
else
    echo "  (no icon PNGs found — using default icon)"
fi

# ── Step 4: Code sign ────────────────────────────────────────────────────────
echo "▸ Code signing…"

codesign \
    --force \
    --deep \
    --sign "$SIGN_IDENTITY" \
    --entitlements "Peak/App/Peak.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE" 2>/dev/null || \
codesign \
    --force \
    --deep \
    --sign "$SIGN_IDENTITY" \
    --entitlements "Peak/App/Peak.entitlements" \
    "$APP_BUNDLE"

echo "  Signature : $(codesign -dv "$APP_BUNDLE" 2>&1 | grep 'Authority\|adhoc' | head -1 || echo 'ad-hoc')"

# ── Done ─────────────────────────────────────────────────────────────────────
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "✅  $APP_BUNDLE ($APP_SIZE)"
echo ""
