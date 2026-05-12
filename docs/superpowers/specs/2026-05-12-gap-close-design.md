# Gap Close: Mockup → Implementation

**Date:** 2026-05-12
**Author:** Travis Frisinger (with Claude)
**Status:** Approved for planning
**Delivery shape:** Single PR (per user direction). Internal commit stacking by phase for review legibility.

## Goal

Close the gap between `mockups/flow.html` and the current SwiftUI/Node implementation so all nine scenes of the design ship.

Today the skeleton (notes list, recording, basic detail, image capture) is present, but the high-value scenes (augmented note rendering, conference grouping, chaptered scrubber, chat) are missing or stubbed. The backend AI pipeline (`blendService`, `chapterizeService`, `anthropic.js`) is largely built and `Note` already persists the structured outputs (`blendedMarkdown`, parallel citation arrays, chapters JSON). The remaining work is mostly iOS rendering plus a new chat backend.

## Scope

In scope (every scene in `mockups/flow.html`):

1. Scene i, Notes list grouped by conference
2. Scene ii, Recording UI polish
3. Scene iii, Background recording + Dynamic Island Live Activity
4. Scene iv, In-app camera with captured-slide strip
5. Scene v, Processing/blending overlay state
6. Scene vi, Augmented note view (the flagship)
7. Scene vii, Conference detail
8. Scene viii, Chat sheet (talk + conference scopes, with citations)
9. Scene ix, Chaptered playback scrubber

Out of scope (explicit non-goals, follow-on candidates):

- iCloud sync, multi-day folders, calendar import
- Embedding-based retrieval for chat (token-budget heuristic is the v1)
- Streaming chat responses (single-shot in v1)
- Server-side chat history persistence (client-only via SwiftData)
- User-visible chat cost display (logged server-side only)
- iOS test coverage gate (no gate added in this PR)

## Architecture Overview

### Data model (iOS / SwiftData)

New entities:

```swift
@Model final class Conference {
    var id: UUID
    var name: String
    var location: String?
    var startDate: Date?
    var endDate: Date?
    var conferenceDescription: String?
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Note.conference)
    var notes: [Note] = []
}

@Model final class ChatThread {
    var id: UUID
    var scopeKind: String   // "talk" | "conference"
    var scopeId: UUID
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    var messages: [ChatMessage] = []
}

@Model final class ChatMessage {
    var id: UUID
    var role: String        // "user" | "assistant"
    var content: String
    var citationsJSON: Data?
    var createdAt: Date
    var thread: ChatThread?
}
```

Changes to `Note`:

- Add `var speaker: String?`
- Add `var conference: Conference?` relationship
- Keep `var conferenceName: String?` for one release as a fallback. New reads go through `conference?.name`. Removable in a follow-on.

### Schema versioning + migration

Use SwiftData `VersionedSchema` chain `SchemaV1 → SchemaV2`. New entities and new optional fields are additive (lightweight migration).

`ConferenceMigration.swift` runs once at app launch:

1. Query `Note` where `conference == nil && conferenceName != nil`.
2. Group by trimmed, case-insensitive `conferenceName`.
3. For each group, find-or-create a `Conference` with that name. Backfill `startDate` and `endDate` from min/max `note.timestamp`. Other metadata stays nil.
4. Attach `note.conference = conference` for each note in the group.
5. Save. Mark migration complete via `UserDefaults` keyed by schema version so it does not re-run.

Idempotent and additive. The original `conferenceName` stays intact so a botched migration is recoverable.

`SampleDataManager` updated to seed two conferences with multi-talk groupings so debug builds exercise the new screens.

### Backend additions

Two new routes, mounted under existing JWT auth:

```
POST /sessions/:sessionId/chat
POST /conferences/:conferenceId/chat
```

Request: `{ messages: [{ role, content }, ...] }` (full thread, server is stateless).
Response: `{ message, citations[], usage }`.

Citation shape:

```json
{ "kind": "transcript", "talkId": "uuid", "startSec": 612.4, "endSec": 624.1, "label": "10:12" }
{ "kind": "note",       "noteId": "uuid", "title": "The three pillars" }
```

`chatService.js` exports `chatTalk(...)` and `chatConference(...)` which delegate to a shared `runChat({ context, messages })`. Context assembly:

- Talk scope: transcript, userNotes, blendedMarkdown, photo OCR summaries for one session.
- Conference scope: for each session under the conference, include a compact summary (title, speaker, date, aiSummary, top OCR snippets). For the 3 most-recent talks (or whatever fits the token budget), include full `blendedMarkdown`. Older talks degrade to summary-only.

System prompt instructs Sonnet to:

- Answer only from supplied context. If unknown, say so.
- Emit citations inline as `[[c:N]]` tokens referencing entries in a `references[]` array it also returns.
- Output strict JSON: `{ answer, references }`.

Server post-processing strips `[[c:N]]` tokens from `answer`, resolves references into the `citations[]` returned to the client (formatting `startSec` as `mm:ss`, resolving note titles), and drops references that fail to resolve.

Guardrails:

- Token budget cap at ~150k input tokens for conference scope.
- `max_tokens` 2000 per turn.
- Rate limit via a new `chatLimiter` key reusing the transcription-tier rate (20 / 15min).
- Authz check confirms the requesting user owns the session or conference before responding.
- Cost tracking via existing `ledgerService` pattern. Not surfaced to users in v1.

### iOS view restructuring

Delete after salvage:

- `SimpleMainView.swift`, `SimpleNoteDetailView.swift`
- `AISummaryEditorView.swift` (salvage edit UX into augmented note overflow sheet)
- `EnhancedNoteEditorView.swift` (salvage formatting toolbar into inline user-notes editor)
- `MyNotesView.swift` (fold pattern into augmented note)

Rename and restyle:

- `SimpleArchiveView` → `ArchiveView`
- `SimpleSettingsView` → `SettingsView`

New views:

- `MainView` (Scene i)
- `ConferenceDetailView` (Scene vii)
- `AugmentedNoteView` (Scene vi)
- `ChapteredPlaybackView` (Scene ix)
- `ChatView` (Scene viii)
- `BlendingOverlay` (Scene v overlay)

Polished in place:

- `NewNoteView` (Scenes ii, iv)
- `WaveformView` (animated bars)

New components:

- `SlideCard`, `ScopeChip`, `CitationChip`, `ChapterScrubber`

Dev-only views (`DebugMenuView`, `DeveloperSettingsView`, `PerformanceView`, `TranscriptView`) stay, but navigation entry points get wrapped in `#if DEBUG`.

### Background recording (Scene iii)

ActivityKit Live Activity with `RecordingAttributes { startedAt, sessionId, title }`.

- Compact leading: red dot. Compact trailing: `mm:ss`.
- Expanded: title, elapsed time, Stop button.
- `AudioRecordingManager` calls `Activity.update(...)` every 1s while recording is active.
- Info.plist gains `UIBackgroundModes: audio` so recording survives backgrounding.
- Tap on Dynamic Island deep-links back to the active `NewNoteView`.

## Component design: Augmented note renderer

This is the flagship and the most subtle piece. Detailed because the renderer is the most testable and most error-prone new code.

Inputs (already persisted on `Note`):

- `blendedMarkdown: String?`
- `blendCitationsJSON: Data?` decodes to `BlendCitations { userNoteSpans, quoteSpans, imagePlacements, citations }`. All four are parallel arrays of char ranges into `blendedMarkdown`.
- `photos: [Photo]` for thumbnail lookup keyed by `photoId` referenced in `imagePlacements`.
- `chaptersJSON: Data?` for "Listen" jump targets.

Render strategy:

1. Parse `blendedMarkdown` into a base `AttributedString` via SwiftUI's markdown initializer.
2. Walk `userNoteSpans` and apply a `.bold()` + accent foreground attribute over each range.
3. Walk `quoteSpans` and apply a quote-block paragraph style (left bar, italic). Attach a custom attribute carrying `startSec` so a tap gesture can read it.
4. Walk `citations` and apply a subtle underline + custom attribute carrying the cited transcript range.
5. For rendering photos at `imagePlacements`, split the `blendedMarkdown` at each offset (ascending) into text segments. Build a `[BlendSegment]` list alternating `.text(AttributedString)` and `.photo(Photo, caption)`. The view body iterates segments in a `VStack` so photos render as full-width cards between paragraphs rather than as inline runs.

Tap handling:

- Tap on a `quoteSpan` or `citation` opens `ChapteredPlaybackView` for this note at `startSec`.
- Photos open `FullscreenImageViewer` (existing component).

Edge cases the renderer must handle (each becomes a unit test):

- `blendedMarkdown` missing or `blendStatus != .complete`: show `BlendingOverlay` or failed state with retry.
- Empty arrays for any of the four parallel structures: render bare markdown without overlays.
- Out-of-range char offsets (defensive against bad model output): clamp and log, do not crash.
- Image placements pointing at a `photoId` no longer in `note.photos`: skip the photo card silently.
- Multiple spans overlapping: last-applied wins; document this in renderer.

## Salvage map

| From | Take | Into |
|---|---|---|
| `AISummaryEditorView` | Summary edit field + save flow | `AugmentedNoteView` overflow → "Edit AI summary" sheet |
| `EnhancedNoteEditorView` | Formatting toolbar component | `AugmentedNoteView` inline `userNotes` editor |
| `MyNotesView` | Personal-notes edit affordance pattern | folded into `AugmentedNoteView` |

## Testing strategy

### API (Jest, existing infra, 70% gate per commit 3a5a0b9)

Unit:

- `chatService.test.js`: context assembly per scope; citation post-processing (token strip + reference resolution); JSON parse failure handling; reference-resolve failure drops the citation; token budget fallback for conference scope. Mock anthropic client like existing `blendService.test.js`.

Integration:

- `chat.routes.test.js`: auth gating (no token → 401), ownership check (wrong user → 403), rate limit hit, happy path with mocked anthropic for both scopes.

### iOS (XCTest)

Unit:

- `BlendRendererTests`: synthetic `blendedMarkdown` + parallel arrays, assert ranges are styled and segment list inserts photos at correct offsets. Covers all edge cases listed above.
- `ConferenceMigrationTests`: fixture of notes with `conferenceName` strings, assert correct `Conference` records created and notes attached. Run migration twice, assert idempotency.
- `ChatServiceTests`: request shape, citation decoding, thread persistence. Mock URLSession.

UI:

- Smoke test through main → conference → note → scrubber → chat sheet. Navigation graph only, no visual assertions.

## Ready-to-ship checklist

Before marking the PR ready for review:

- `./scripts/lint.sh` clean
- `./scripts/test.sh all` green
- `cd src/api && npm test` green at 70%+ coverage
- Manual smoke on simulator covering: record, blend pipeline runs to `.complete`, augmented note renders with overlays, conference grouping shows on main, scrubber seeks and respects chapters, chat works for both scopes with tappable citations, background recording survives backgrounding with Dynamic Island

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Single mega-PR is hard to review and revert | Stack commits inside the PR by phase so reviewers can walk scene-by-scene. Feature-flag chat routes so prod can disable without revert. |
| SwiftData migration on real user data is destructive if wrong | Migration is additive (keeps `conferenceName` field), idempotent (guarded by UserDefaults key), and write-on-launch (no migration during normal use). |
| Sonnet returning malformed JSON for chat | `chatService` mirrors `blendService` parse-or-throw pattern. Route returns 502 with a user-facing message; iOS surfaces a retry. |
| Conference-scope chat exceeds token budget | Heuristic (summaries + N recent full blends) implemented in `chatService` with explicit cap. Embedding retrieval is the v2 path. |
| Live Activity not supported on older devices | Feature-gate on `ActivityKit.Activity.activitiesEnabled`. Graceful fallback to a plain in-app banner. |
| Augmented note renderer crashes on bad span offsets | Defensive clamping + logging. Unit tests cover overlapping/out-of-range spans. |

## Phased implementation order (within the single PR)

This order minimizes time spent on broken intermediate states.

1. **Schema + migration** (additive, no UI yet)
2. **Backend `chatService` + routes + tests** (independently testable; feature-flagged)
3. **`BlendRenderer` + `AugmentedNoteView`** (highest test value, unblocks most scenes). Salvaged UX from `AISummaryEditorView` and `EnhancedNoteEditorView` lands here.
4. **`MainView` + `ConferenceDetailView`** (depends on schema). Renames of `Simple*Archive`/`Settings` happen here.
5. **`ChapteredPlaybackView`** (depends on renderer's citation taps)
6. **`ChatView` + iOS `ChatService`** (depends on backend)
7. **`NewNoteView` polish + `WaveformView` rework**
8. **Live Activity / Dynamic Island**
9. **Delete orphaned view files** (`AISummaryEditorView`, `EnhancedNoteEditorView`, `MyNotesView`, `SimpleNoteDetailView`, `SimpleMainView`) once their salvage targets are in place
10. **Sample data refresh, manual smoke, ship**

## Open follow-ons (post-merge)

- Remove `Note.conferenceName` after one release.
- Embedding-based retrieval for conference-scope chat as corpus grows.
- Streaming chat responses if perceived latency is an issue.
- iOS code coverage gate.
- Server-side chat persistence + sync.
