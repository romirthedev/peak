# Peak

> Perfect recall of everything you do on your Mac — powered by local AI.

Peak is a macOS menu bar app that quietly records your screen and audio in the background, extracts meaning from it with local AI, and gives you a conversational interface to recall, search, and act on anything you've ever worked on.

**Everything stays on your machine. No cloud. No subscriptions.**

---

## What Peak does

| Feature | How |
|---|---|
| Screen memory | Captures screenshots every 5 s, runs OCR via Vision framework |
| Meeting recall | Records microphone audio in 30 s segments, transcribes locally with Whisper |
| Activity tracking | Tracks active app, window title, and browser URL |
| Semantic search | Embeds all captured text with `nomic-embed-text` via Ollama |
| AI Q&A | Streams answers from any local Ollama model with context injected |
| Timeline | Visual log of everything you did, browseable by date |

---

## Architecture

```
Peak/
├── App/
│   ├── PeakApp.swift            # @main SwiftUI entry point
│   └── AppDelegate.swift        # NSStatusItem menu bar setup
├── Models/
│   ├── Screenshot.swift
│   ├── AudioSegment.swift
│   ├── ActivityEvent.swift
│   ├── ChatMessage.swift
│   └── SearchResult.swift
├── Services/
│   ├── ScreenCaptureService.swift   # Periodic CGDisplayCreateImage + permission check
│   ├── OCRService.swift             # Vision VNRecognizeTextRequest
│   ├── AudioCaptureService.swift    # AVAudioEngine mic capture, rolling segments
│   ├── TranscriptionService.swift   # WhisperKit local transcription
│   ├── ActivityMonitorService.swift # NSWorkspace + CGWindowList polling
│   ├── StorageService.swift         # SQLite.swift local database
│   ├── EmbeddingService.swift       # Ollama /api/embeddings + cosine similarity
│   ├── AIService.swift              # Ollama /api/chat streaming
│   └── RecordingOrchestrator.swift  # @MainActor coordinator / @Published state
├── Views/
│   ├── MenuBarView.swift            # Popover from status item
│   ├── MainWindowView.swift         # NavigationSplitView shell
│   ├── ChatView.swift               # Streaming chat UI
│   ├── TimelineView.swift           # HSplitView activity log + app usage
│   ├── OnboardingView.swift         # 3-step first-run flow
│   └── SettingsView.swift           # Form with all preferences
└── Utilities/
    ├── Constants.swift
    └── Extensions.swift
```

### Data flow

```
Screen → ScreenCaptureService → OCRService → StorageService (SQLite)
                                           → EmbeddingService (Ollama) → StorageService

Mic → AudioCaptureService → TranscriptionService (Whisper) → StorageService
                                                           → EmbeddingService → StorageService

Activity → ActivityMonitorService → StorageService

User query → EmbeddingService (query vector)
           → cosine similarity over all stored embeddings
           → top-N context chunks → AIService (Ollama, streaming) → ChatView
```

---

## Requirements

| Dependency | Version | Purpose |
|---|---|---|
| macOS | 13.0+ | Minimum deployment target |
| Xcode | 15+ | Build toolchain |
| [Ollama](https://ollama.ai) | latest | Local LLM & embedding inference |
| XcodeGen | any | Generate `.xcodeproj` from `project.yml` |

---

## Setup

```bash
# Clone the repo
git clone <repo-url> peak && cd peak

# Run the automated setup script
./setup.sh
```

The script will:
1. Install Homebrew (if needed)
2. Install XcodeGen via Homebrew
3. Pull `llama3.2` and `nomic-embed-text` from Ollama
4. Generate `Peak.xcodeproj`

Then open the project in Xcode, set your Development Team, and hit **⌘R**.

### Manual setup

```bash
# Install XcodeGen
brew install xcodegen

# Install & start Ollama
# → https://ollama.ai

# Pull models
ollama pull llama3.2
ollama pull nomic-embed-text

# Generate Xcode project
xcodegen generate

# Open in Xcode
open Peak.xcodeproj
```

---

## Permissions

Peak requires the following macOS permissions (granted via the onboarding flow):

- **Screen Recording** — `System Settings → Privacy & Security → Screen Recording`
- **Microphone** — requested at runtime
- **Accessibility** — for reading window titles (`System Settings → Privacy & Security → Accessibility`)

---

## Configuration

All settings are in the **Settings** tab inside Peak:

| Setting | Default | Description |
|---|---|---|
| Capture interval | 5 s | How often a screenshot is taken |
| Language model | `llama3.2` | Ollama model used for chat |
| Whisper model | `openai_whisper-base` | Transcription accuracy vs. speed trade-off |
| Retention | 30 days | Automatically delete data older than N days |

---

## Privacy & Security

- All captured data is stored in `~/Library/Application Support/Peak/`
- No data ever leaves your machine
- The app has no network entitlement except for `localhost:11434` (Ollama)
- App Sandbox is disabled to allow screen recording and microphone access (standard for this class of app)
- You can delete everything at any time via **Settings → Clear All Data**

---

## Local database

SQLite database lives at:

```
~/Library/Application Support/Peak/peak.db
```

Tables: `screenshots`, `audio_segments`, `activity_events`, `embeddings`

---

## Roadmap

- [ ] System audio capture (meeting output, not just mic)
- [ ] Automatic daily summaries
- [ ] Writing style analysis and ghost-writing
- [ ] Spotlight / Quick Look integration
- [ ] iCloud sync (encrypted) — opt-in
- [ ] iOS companion app

---

## Contributing

Pull requests are welcome. Please open an issue first for large changes.

---

## License

MIT
