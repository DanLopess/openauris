# OpenAuris

OpenAuris is an open-source, privacy-first dictation app for macOS.

It is designed as a lightweight Apple-native alternative to hosted whisper apps, with local-only processing, global shortcuts, and a polished menu bar workflow.

## Current V1 Implementation

- Menu bar-first app shell with dashboard window.
- Bottom-center listening bubble overlay with live status.
- Two dictation trigger modes:
  - Hold to speak.
  - Toggle start/stop.
- App Intents shortcuts for automations in Apple Shortcuts.
- Model management UI with auto-install flow for the default model.
- Session history with search and deletion.
- Local stats:
  - Total words.
  - Session count.
  - Average WPM.
  - Current streak.
- Achievements:
  - First Session.
  - 1,000 Words.
  - 7-Day Streak.
  - 25 Sessions.
  - 10,000 Words.
- Local-only storage via SwiftData.
- Accessibility-first text insertion with paste fallback.

## Whisper Runtime

`WhisperKitTranscriptionEngine` is implemented and compiles with a fallback mode when WhisperKit is not linked.

To enable full WhisperKit transcription, add package dependency:

- Repository: `https://github.com/argmaxinc/WhisperKit.git`
- Product: `WhisperKit`

## Requirements

- macOS 26+
- Apple Silicon
- Xcode 26.2+

## Build

```bash
xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' build
```

## Test

```bash
xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' -only-testing:openaurisTests test
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)
