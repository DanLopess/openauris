# Contributing to OpenAuris

## Setup

1. Open `openauris.xcodeproj` in Xcode 26.2+.
2. Select the `openauris` scheme.
3. Build for `My Mac`.

## Development Principles

- Keep transcription local-only.
- Prefer Apple-native frameworks and lightweight dependencies.
- Preserve menu bar-first UX and low-latency dictation behavior.

## Testing

Run before opening a PR:

```bash
xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' build
xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' -only-testing:openaurisTests test
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for module boundaries and data flow.
