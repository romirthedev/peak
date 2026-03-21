#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Peak — build script
#
# Produces a code-signed, universal (arm64 + x86_64) Peak.app bundle using
# Swift Package Manager. No Xcode IDE required — only Xcode Command Line Tools.
#
# Usage:
#   ./scripts/build.sh                     # ad-hoc signed (dev)
#   SIGN_IDENTITY="Developer ID Application: You (TEAMID)" ./scripts/build.sh
#   VERSION=1.2.0 ./scripts/build.sh
#
# Requirements:
#   xcode-select --install   (Xcode Command Line Tools)
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

# Signing identity: "-" = ad-hoc (no Apple account needed, shows Gatekeeper warning)
# Set SIGN_IDENTITY env var to "Developer ID Application: ..." for notarization-ready builds
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

# ── Step 1: Compile for each arch separately, then lipo-merge ─────────────────
echo "▸ Compiling arm64…"
swift build -c release --arch arm64
echo ""

echo "▸ Compiling x86_64…"
swift build -c release --arch x86_64
echo ""

ARM_BIN=".build/arm64-apple-macosx/release/$APP_NAME"
X86_BIN=".build/x86_64-apple-macosx/release/$APP_NAME"

if [ ! -f "$ARM_BIN" ] || [ ! -f "$X86_BIN" ]; then
    echo "❌  Could not find compiled binaries."
    echo "    Expected:"
    echo "      $ARM_BIN"
    echo "      $X86_BIN"
    exit 1
fi

# ── Step 2: Assemble .app bundle ──────────────────────────────────────────────
echo "▸ Assembling $APP_NAME.app…"

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Universal binary
lipo -create "$ARM_BIN" "$X86_BIN" -output "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"

echo "  Binary arch: $(lipo -archs "$CONTENTS/MacOS/$APP_NAME")"

# Info.plist (inject real version number)
sed "s/1\.0\.0/$VERSION/g" "Peak/App/Info.plist" > "$CONTENTS/Info.plist"

# ── Step 3: Compile asset catalog (icon etc.) ─────────────────────────────────
if xcrun --find actool &>/dev/null 2>&1; then
    echo "▸ Compiling asset catalog…"
    xcrun actool "Peak/Assets.xcassets" \
        --compile "$CONTENTS/Resources" \
        --platform macosx \
        --minimum-deployment-target "$MIN_MACOS" \
        --app-icon AppIcon \
        --output-partial-info-plist "/tmp/${APP_NAME}-actool.plist" \
        2>/dev/null || echo "  (asset catalog: no icon images found — using default)"
else
    echo "  (actool not found — skipping icon compilation)"
fi

# ── Step 4: Code sign ─────────────────────────────────────────────────────────
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

# ── Done ──────────────────────────────────────────────────────────────────────
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "✅  $APP_BUNDLE ($APP_SIZE)"
echo ""
