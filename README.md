# Peak

> Perfect recall of everything you do on your Mac — powered by local AI.

Peak is a macOS menu bar app that quietly records your screen and audio in the background, extracts meaning from it with local AI, and gives you a conversational interface to recall, search, and act on anything you've ever worked on.

**Everything stays on your machine. No cloud. No subscriptions.**

---

## For users — install in 30 seconds

1. Download **Peak.dmg** from the [Releases page](../../releases/latest)
2. Open the DMG → drag **Peak.app** to your Applications folder
3. Launch Peak from Applications (or Spotlight: `⌘Space` → "Peak")
4. Grant Screen Recording + Microphone when prompted
5. Install [Ollama](https://ollama.ai) and run:

```bash
ollama pull llama3.2
ollama pull nomic-embed-text
```

6. Click the waveform icon in your menu bar → **Start Recording**

> **Gatekeeper note:** Until the app is notarized, macOS may warn you on first launch.
> Right-click `Peak.app` → **Open** once to bypass it.

---

## For developers — build from source

Xcode IDE is **not** required. You only need Xcode Command Line Tools (~500 MB vs Xcode's ~10 GB).

```bash
# One-time setup
./setup.sh

# Build Peak.app + DMG
./scripts/build.sh
./scripts/create-dmg.sh

# Output: .build/Peak-1.0.0.dmg
```

### Auto-release via GitHub Actions

Push a version tag and the CI pipeline builds a universal DMG and publishes it as a GitHub Release automatically:

```bash
git tag v1.0.0
git push origin v1.0.0
# → .github/workflows/release.yml runs on a macOS runner
# → Peak-1.0.0.dmg appears in Releases, ready to link from your website
```

Your website's download button just needs to point to:
```
https://github.com/<you>/peak/releases/latest/download/Peak-<VERSION>.dmg
```

---

## Architecture

```
Peak/
├── App/
│   ├── PeakApp.swift            # @main SwiftUI entry point
│   ├── AppDelegate.swift        # NSStatusItem menu bar + window management
│   ├── Info.plist               # Bundle metadata, privacy descriptions
│   └── Peak.entitlements        # Microphone, network (localhost), file access
├── Models/
│   ├── Screenshot.swift
│   ├── AudioSegment.swift
│   ├── ActivityEvent.swift
│   ├── ChatMessage.swift
│   └── SearchResult.swift
├── Services/
│   ├── ScreenCaptureService.swift   # CGDisplayCreateImage every N seconds
│   ├── OCRService.swift             # Vision VNRecognizeTextRequest (local)
│   ├── AudioCaptureService.swift    # AVAudioEngine, rolling 30-second segments
│   ├── TranscriptionService.swift   # WhisperKit (local, on-device)
│   ├── ActivityMonitorService.swift # NSWorkspace + CGWindowList + AppleScript
│   ├── StorageService.swift         # SQLite.swift — all data stored locally
│   ├── EmbeddingService.swift       # Ollama nomic-embed-text + cosine similarity
│   ├── AIService.swift              # Ollama streaming chat completions
│   └── RecordingOrchestrator.swift  # @MainActor coordinator / @Published state
├── Views/
│   ├── MenuBarView.swift            # NSStatusItem popover
│   ├── MainWindowView.swift         # NavigationSplitView shell
│   ├── ChatView.swift               # Streaming Q&A chat
│   ├── TimelineView.swift           # Activity log + app usage chart
│   ├── OnboardingView.swift         # 3-step first-run flow
│   └── SettingsView.swift           # All preferences
└── Utilities/
    ├── Constants.swift
    └── Extensions.swift

Package.swift                    # Swift Package Manager manifest
scripts/
├── build.sh                     # Builds universal Peak.app
└── create-dmg.sh                # Packages Peak.app into a DMG
.github/workflows/
└── release.yml                  # CI/CD: tag → build → GitHub Release
```

### Data flow

```
Screen → ScreenCaptureService ──→ OCRService        ──→ StorageService (SQLite)
                                                     └─→ EmbeddingService (Ollama) → StorageService

Mic    → AudioCaptureService  ──→ TranscriptionService ──→ StorageService
                                  (WhisperKit local)   └─→ EmbeddingService → StorageService

User   → NSWorkspace/CGWindowList ──→ StorageService

Query  → EmbeddingService (embed query)
       → cosine similarity over all embeddings
       → top-N context chunks
       → AIService (Ollama, streaming) → ChatView
```

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS 13 Ventura+ | Deployment target |
| [Ollama](https://ollama.ai) | Local AI inference — runs on your Mac |
| Xcode CLT (dev only) | `xcode-select --install` — **not** full Xcode |

---

## Configuration

All settings are in the **Settings** tab inside Peak:

| Setting | Default | Description |
|---|---|---|
| Capture interval | 5 s | How often a screenshot is taken |
| Language model | `llama3.2` | Ollama model used for chat |
| Whisper model | `openai_whisper-base` | Transcription speed vs. accuracy |
| Retention | 30 days | Auto-delete data older than N days |

---

## Signed & notarized distribution (optional)

For a seamless first-launch experience with no Gatekeeper warning:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Create a **Developer ID Application** certificate in Xcode
3. Add these secrets to your GitHub repo:
   - `SIGN_IDENTITY` → `Developer ID Application: Your Name (TEAMID)`
   - `APPLE_ID` → your Apple ID email
   - `APPLE_TEAM_ID` → your 10-character team ID
   - `APPLE_APP_PASSWORD` → an app-specific password from appleid.apple.com
4. Uncomment the `Notarize` step in `.github/workflows/release.yml`

---

## Privacy

- All data is stored in `~/Library/Application Support/Peak/`
- Nothing ever leaves your Mac
- The only network calls go to `localhost:11434` (Ollama)
- You can delete everything at any time: **Settings → Clear All Data**

---

## License

MIT
