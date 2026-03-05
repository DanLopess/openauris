# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Requirements

- macOS 26+, Apple Silicon
- Xcode 26.2+
- WhisperKit is a **required** dependency — transcription will not compile without it

## Commands

**Build:**
```bash
xcodebuild -project openauris.xcodeproj -scheme OpenAuris -destination 'platform=macOS' -configuration Debug -derivedDataPath .build build
```

**Run app (terminal):**
```bash
xcodebuild -project openauris.xcodeproj -scheme OpenAuris -destination 'platform=macOS' -configuration Debug -derivedDataPath .build build
open .build/Build/Products/Debug/OpenAuris.app
```

**Run all unit tests:**
```bash
xcodebuild -project openauris.xcodeproj -scheme OpenAuris -destination 'platform=macOS' -configuration Debug -derivedDataPath .build -only-testing:OpenAurisTests test
```

**Run a single test class:**
```bash
xcodebuild -project openauris.xcodeproj -scheme OpenAuris -destination 'platform=macOS' -configuration Debug -derivedDataPath .build -only-testing:OpenAurisTests/AppRepositoryTests test
```

**VS Code tasks:**
- `Build OpenAuris`: build Debug to `.build`
- `Run OpenAuris`: depends on build, then `open .build/Build/Products/Debug/OpenAuris.app`
- `Run Tests`: test target `OpenAurisTests` with `.build` derived data

`xcodebuild ... run` is not a valid build action in this setup.

## Architecture

The app is a macOS menu bar app built with SwiftUI + SwiftData. Shared app state uses Swift Observation (`@Observable`) and is wired together in `AppContainer` (the app's composition root).

### Layers (`docs/ARCHITECTURE.md`)

| Layer | Key files |
|---|---|
| AppLayer | `AppContainer.swift`, `openaurisApp.swift` |
| SessionLayer | `DictationSessionManager.swift` |
| AudioLayer | `Services/Audio/AudioCaptureService.swift` |
| EngineLayer | `Core/TranscriptionEngine.swift` (protocol), `Services/Engine/WhisperKitTranscriptionEngine.swift` |
| InsertionLayer | `Services/Insertion/AccessibilityTextInsertionService.swift` |
| ModelLayer | `Services/Models/WhisperModelManager.swift` |
| DataLayer | `Data/AppRepository.swift` + SwiftData entities |
| OverlayLayer | `Services/Overlay/OverlayPanelController.swift`, `UI/Overlay/ListeningBubbleView.swift` |
| ShortcutsLayer | `Services/Shortcuts/GlobalHotkeyManager.swift` (Carbon APIs) |
| IntentsLayer | `AppIntents/` |

### Main dictation flow

1. Global hotkey → `GlobalHotkeyManager` fires action → `DictationSessionManager.handleHotkeyAction(_:)`
2. `DictationSessionManager` drives state: `.idle` → `.listening(mode)` → `.processing` → `.inserting` → `.idle`
3. Audio frames from `AudioCaptureService.onFrame` are forwarded to `TranscriptionEngine.appendAudioFrame(_:)`
4. Partial text is polled every 150 ms and inserted incrementally via `AccessibilityTextInsertionService`
5. On stop, `finishStreaming()` returns `FinalTranscript`; text is finalised, session saved, stats/achievements recomputed

### Key protocols and contracts

- `TranscriptionEngine` — `prepare` → `startStreaming` → (`appendAudioFrame` loop) → `finishStreaming` / `cancelStreaming`
- `TextInsertionService` — `insert(_:)` returns `InsertionResult` (.insertedDirectly / .insertedViaPasteFallback / .failed)

### Persistence

SwiftData entities via `AppRepository` (main context only, all calls `@MainActor`):
`DictationSessionEntity`, `ModelInstallEntity`, `DailyStatsEntity`, `AchievementEntity`, `UserPreferenceEntity`


## Development principles

- Keep transcription local-only — no network calls for audio/text.
- Prefer Apple-native frameworks; minimise third-party dependencies.
- Preserve menu bar-first UX and low-latency dictation behaviour.
- **A task is not complete until the project builds successfully and all tests pass.** Always run the build command after making changes before declaring work done.
