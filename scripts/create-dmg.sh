#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Peak — DMG packaging script
#
# Takes the Peak.app built by scripts/build.sh and wraps it in a DMG that
# users can download, open, and drag to /Applications.
#
# Usage:
#   ./scripts/create-dmg.sh
#   VERSION=1.2.0 ./scripts/create-dmg.sh
#
# Output: .build/Peak-<VERSION>.dmg
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_NAME="Peak"
VERSION="${VERSION:-1.0.0}"
BUILD_ROOT=".build"
STAGING="$BUILD_ROOT/staging"
APP_BUNDLE="$STAGING/$APP_NAME.app"
DMG_STAGE="$BUILD_ROOT/dmg-stage"
OUTPUT_DMG="$BUILD_ROOT/${APP_NAME}-${VERSION}.dmg"
VOL_NAME="${APP_NAME} ${VERSION}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌  $APP_BUNDLE not found. Run scripts/build.sh first."
    exit 1
fi

echo "▸ Staging DMG contents…"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"

# Copy the app
cp -R "$APP_BUNDLE" "$DMG_STAGE/"

# Symlink to /Applications so users see the "drag here" affordance
ln -sf /Applications "$DMG_STAGE/Applications"

# ── Optional: background image ────────────────────────────────────────────────
# If you have a DMG background at assets/dmg-background.png, uncomment:
# mkdir -p "$DMG_STAGE/.background"
# cp assets/dmg-background.png "$DMG_STAGE/.background/background.png"

# ── Create compressed DMG ─────────────────────────────────────────────────────
echo "▸ Creating DMG…"

rm -f "$OUTPUT_DMG"

hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$OUTPUT_DMG"

rm -rf "$DMG_STAGE"

# ── Summary ───────────────────────────────────────────────────────────────────
DMG_SIZE=$(du -sh "$OUTPUT_DMG" | cut -f1)
echo ""
echo "✅  $OUTPUT_DMG ($DMG_SIZE)"
echo ""
echo "Users: download → double-click DMG → drag $APP_NAME to Applications → open it"
echo ""
