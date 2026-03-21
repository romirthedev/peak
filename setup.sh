#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Peak — developer setup script
#
# Sets up everything needed to BUILD Peak from source.
# End USERS don't run this — they just download the DMG from the releases page.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Peak — Developer Setup           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Xcode Command Line Tools ───────────────────────────────────────────────
# Full Xcode IDE is NOT required. CLT provides: swift, swiftc, lipo, actool, codesign.
if ! xcode-select -p &>/dev/null; then
    echo "📦 Installing Xcode Command Line Tools…"
    xcode-select --install
    echo ""
    echo "⚠️  Finish the CLT installer, then re-run this script."
    exit 0
else
    echo "✅  Xcode Command Line Tools: $(xcode-select -p)"
fi

# ── 2. Swift version check ────────────────────────────────────────────────────
SWIFT_VERSION=$(swift --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "✅  Swift $SWIFT_VERSION"

# ── 3. Ollama ─────────────────────────────────────────────────────────────────
if ! command -v ollama &>/dev/null; then
    echo ""
    echo "⚠️  Ollama is not installed."
    echo "    Peak needs Ollama to run the local AI models."
    echo "    Download it from: https://ollama.ai"
    echo ""
    open "https://ollama.ai" 2>/dev/null || true
    echo "    After installing, re-run this script."
    exit 0
else
    echo "✅  Ollama: $(ollama --version 2>/dev/null || echo 'installed')"

    echo ""
    echo "📥 Pulling required AI models (first time may take a few minutes)…"

    echo "   → llama3.2  (language model for chat)"
    ollama pull llama3.2

    echo "   → nomic-embed-text  (embedding model for semantic search)"
    ollama pull nomic-embed-text

    echo ""
    echo "   Whisper (speech-to-text) is downloaded automatically on first launch."
fi

# ── 4. Resolve Swift packages ─────────────────────────────────────────────────
echo ""
echo "▸ Resolving Swift Package Manager dependencies…"
swift package resolve

# ── 5. Quick build check ──────────────────────────────────────────────────────
echo ""
read -r -p "▸ Run a debug build now to verify everything compiles? [Y/n] " choice
choice="${choice:-Y}"
if [[ "$choice" =~ ^[Yy]$ ]]; then
    swift build
    echo "✅  Debug build succeeded."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "✅  Developer setup complete!"
echo ""
echo "To build a distributable app:"
echo ""
echo "  ./scripts/build.sh          # builds Peak.app"
echo "  ./scripts/create-dmg.sh     # packages into Peak-1.0.0.dmg"
echo ""
echo "To release automatically via GitHub Actions:"
echo "  git tag v1.0.0 && git push origin v1.0.0"
echo ""
echo "The DMG will appear in your GitHub Releases page,"
echo "ready to link from your website's download button."
echo "═══════════════════════════════════════════"
echo ""
