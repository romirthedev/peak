#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           Peak — Setup Script            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "📦 Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅  Homebrew already installed"
fi

# ── 2. XcodeGen ──────────────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  echo "📦 Installing XcodeGen…"
  brew install xcodegen
else
  echo "✅  XcodeGen already installed"
fi

# ── 3. Ollama ─────────────────────────────────────────────────────────────────
if ! command -v ollama &>/dev/null; then
  echo ""
  echo "⚠️  Ollama is not installed."
  echo "    Please install it from https://ollama.ai and re-run this script."
  echo ""
  open "https://ollama.ai" 2>/dev/null || true
else
  echo "✅  Ollama found at $(which ollama)"
  echo ""
  echo "📥 Pulling required models (this may take a few minutes)…"

  echo "   → llama3.2 (language model)"
  ollama pull llama3.2

  echo "   → nomic-embed-text (embedding model)"
  ollama pull nomic-embed-text

  echo ""
  echo "📥 Whisper will be downloaded automatically on first launch by WhisperKit."
fi

# ── 4. Generate Xcode project ─────────────────────────────────────────────────
echo ""
echo "🔨 Generating Xcode project with XcodeGen…"
xcodegen generate

echo ""
echo "═══════════════════════════════════════════"
echo "✅  Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open Peak.xcodeproj in Xcode"
echo "  2. Set your Development Team in Signing & Capabilities"
echo "  3. Build & Run (⌘R)"
echo ""
echo "Peak will appear in your menu bar."
echo "Click the waveform icon → 'Start Recording' to begin."
echo "═══════════════════════════════════════════"
echo ""
