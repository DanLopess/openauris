# CLAUDE.md

Rules and conventions for Claude Code when working in this repository. For commands, requirements, architecture, and flows — see `README.md` and `docs/ARCHITECTURE.md`.

---

## Hard Rules

- **Never install a new dependency without asking first.**
- **Don't create features that weren't explicitly requested.**
- **Don't modify or refactor working code unless explicitly asked to.**
- **A feature or fix is not complete until the project builds and all tests pass.**
- **Every new feature must include tests — unit tests at minimum, UI tests where applicable.**

---

## Stack & Conventions

- **Language:** Swift 6, strict concurrency. All UI and session state is `@MainActor`.
- **UI:** SwiftUI + SwiftData. Menu bar-first. No UIKit.
- **State:** Swift Observation (`@Observable`). No `ObservableObject` or Combine.
- **Persistence:** SwiftData via `AppRepository` (main context only, all calls `@MainActor`).
- **Async:** Structured concurrency (`async/await`, `Task`, `actor`). No callbacks or GCD.
- **Transcription:** Local-only via WhisperKit. No network calls for audio or text.
- **Dependencies:** Apple-native frameworks preferred. Third-party only when unavoidable and pre-approved.

---

## Code Patterns

- Wire dependencies in `AppContainer` (composition root) — not inside views or services.
- Expose behaviour through protocols (`TranscriptionEngine`, `TextInsertionService`, etc.), inject concrete types at the app layer.
- Services are actors or `@MainActor` classes — never plain structs with mutable state.
- SwiftData entities are only accessed via `AppRepository`. Never use `ModelContext` directly in views or services.
- Use `InsertionResult` return values — don't swallow or ignore them.

---

## Testing Rules

- Run tests with: `xcodebuild -project openauris.xcodeproj -scheme OpenAuris -destination 'platform=macOS' -configuration Debug -derivedDataPath .build -only-testing:OpenAurisTests test`
- New logic = new unit tests. New UI behaviour = new UI tests if testable.
- Tests must cover the happy path and at least one failure/edge case.
- Do not delete or skip existing tests to make a build pass.

---

## What Not To Do

- Don't add comments, docstrings, or type annotations to code you didn't change.
- Don't add error handling for scenarios that can't happen.
- Don't create helpers or abstractions for one-time use.
- Don't add backwards-compatibility shims or feature flags unless asked.
- Don't use `force try` (`try!`) or force unwraps (`!`) in production code.

---

## Response Format

At the end of every task response, include a concise summary that covers:
- **Root cause** — what was wrong and why
- **What changed** — files and lines modified, and what each change does
- **Why it works** — the mechanism that makes the fix correct
- **Local vs CI gap** — if applicable, why the issue only surfaced in one environment

Keep it tight: bullet points, no padding, no repetition of what was already explained above.
