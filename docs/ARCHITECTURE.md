# OpenAuris Architecture

## Layers

- `AppLayer`: menu bar shell, dashboard windows, onboarding.
- `SessionLayer`: dictation state orchestration.
- `AudioLayer`: `AVAudioEngine` microphone capture and level metering.
- `EngineLayer`: `TranscriptionEngine` protocol + `WhisperKitTranscriptionEngine` implementation (with fallback when WhisperKit is not linked).
- `InsertionLayer`: accessibility insertion first, clipboard paste fallback.
- `ModelLayer`: model catalog, install state, default model selection.
- `DataLayer`: SwiftData entities and repository logic for sessions, stats, achievements, preferences.
- `OverlayLayer`: bottom-center listening bubble via non-activating `NSPanel`.
- `ShortcutsLayer`: global hotkeys via Carbon APIs.
- `IntentsLayer`: App Intents shortcuts for system Shortcuts automation.

## Main Flow

1. Global shortcut event triggers `DictationSessionManager`.
2. Audio capture starts and streams `AudioFrame` chunks to the transcription engine.
3. Partial text and audio level update the overlay bubble.
4. Session stop finalizes transcript.
5. Text insertion is attempted with accessibility, then paste fallback.
6. Session is persisted; stats and achievements are recomputed.

## Persistence

SwiftData entities:

- `DictationSessionEntity`
- `ModelInstallEntity`
- `DailyStatsEntity`
- `AchievementEntity`
- `UserPreferenceEntity`

## Distribution

- First channel: direct signed+notarized DMG.
- CI workflow builds and runs unit tests.
- Release workflow includes archive/export/DMG/notarization steps.
