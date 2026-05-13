# Phases 7-10 (Combined): Polish, Live Activity, Cleanup, Sample Data

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** Land the final four phases as one PR-end push:
- **Phase 7** — `NewNoteView` polish + `WaveformView` rework so the recording screen matches the mockup.
- **Phase 8** — ActivityKit Live Activity scaffolding for background recording / Dynamic Island. Includes the `ActivityAttributes` type, `AudioRecordingManager` hooks, and Info.plist background mode. The Live Activity widget extension target itself must be added in Xcode (cannot be created from code); this PR ships the in-app scaffolding so Adding That Target is the only remaining manual step.
- **Phase 9** — Delete the orphaned views replaced by Phases 3-4 (`SimpleMainView`, `SimpleNoteDetailView`, `AISummaryEditorView`, `EnhancedNoteEditorView`, `MyNotesView`). Their tests come along.
- **Phase 10** — Refresh `SampleDataManager` so seeded notes carry a `backendSessionId`. Manual smoke checklist.

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Scenes ii, iii, and § Salvage, Cleanup, Testing.

---

## Phase 7 — Recording polish

**WaveformView:** widen from 5 bars to a denser 24-bar set with mockup-matching heights derived from `audioLevel`. Replace the solid-green fill with a colour that adapts to the system theme.

**NewNoteView controls:** the existing record button is fine; promote the stop affordance to a square `stop.fill` icon for the mockup look. Confirm Pause is still reachable.

Both edits are visual; no unit-test additions (the existing live-update logic is unchanged).

## Phase 8 — Live Activity scaffolding

**Files (production):**
- `src/mobile/Muesli/LiveActivity/RecordingActivityAttributes.swift` — `ActivityAttributes` shared with the widget extension once it's added.
- `src/mobile/Muesli/LiveActivity/LiveActivityController.swift` — `@MainActor` controller that `Activity<RecordingActivityAttributes>.request` on start, `update` every second, `end` on stop. Wraps `if #available(iOS 16.2, *)` and `ActivityAuthorizationInfo().areActivitiesEnabled` so the integration is a no-op when the user has disabled them.
- `src/mobile/Muesli/AudioRecordingManager.swift` — call `LiveActivityController.shared.start/update/end` from the recording lifecycle. Guarded for DEBUG and gracefully degraded if `areActivitiesEnabled == false`.

**Info.plist:** add `UIBackgroundModes` with `audio` so the recording survives backgrounding.

**Cannot do from code:** adding the Widget Extension target itself. The actual `RecordingActivity` Live Activity UI lives in that target; we drop a placeholder doc-comment in `RecordingActivityAttributes.swift` pointing the reader at how to add the target. Until then the controller's `start()` returns gracefully (`areActivitiesEnabled` returns false without a hosting extension).

## Phase 9 — Salvage cleanup

**Delete (after confirming nothing references them):**
- `src/mobile/Muesli/Views/SimpleMainView.swift` (replaced by `MainView`)
- `src/mobile/Muesli/Views/SimpleNoteDetailView.swift` (replaced by `AugmentedNoteView`)
- `src/mobile/Muesli/Views/AISummaryEditorView.swift` (no consumer)
- `src/mobile/Muesli/Views/EnhancedNoteEditorView.swift` (no consumer)
- `src/mobile/Muesli/Views/MyNotesView.swift` (no consumer)
- Matching tests: `MuesliTests/Views/AISummaryEditorViewTests.swift`, `MuesliTests/Views/EnhancedNoteEditorViewTests.swift`, `MuesliTests/Views/NewNoteViewFallbackTests.swift`'s SimpleMain references, `MuesliTests/Views/SimpleMainViewFallbackTests.swift`

After deletion: `grep -r SimpleMainView src/` to confirm no dangling references. Build + run tests to confirm the suite still passes.

## Phase 10 — Sample data + smoke

`SampleDataManager.generateSampleNotes` now sets `backendSessionId = note.id` for every seeded talk so chat works in debug builds against a backend that has matching seed sessions (or just to verify the iOS-side flow with the API stubbed/down).

Manual smoke checklist:
- Cold launch shows `MainView` with `DataSummit 2026` and `DevWorld 2026` sections.
- Tap a talk → AugmentedNoteView renders. (Sample data has no `blendedMarkdown`, so the blend-status fallback shows.)
- Tap conference header → ConferenceDetailView shows hero + talks list + active Chat button.
- Tap Chat → ChatView opens with the scope chip.
- Tap Listen on a note with audio → ChapteredPlaybackView appears.
- Background the app while recording → Dynamic Island banner (only if widget extension target was added; otherwise the app keeps recording but the banner doesn't appear).

---

## Done when

- All four phases committed.
- iOS test suite passes (the deleted view tests should be the only delta).
- Build + lint clean.
- Final cross-task review captures any drift.
