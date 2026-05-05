# Capture Loop Hardening — Design

Date: 2026-05-04
Status: Draft (pending user review)

## Summary

Targeted bug-fix pass on the existing record/photo/notes capture loop. Scoped to issues that survive the upcoming AI pipeline rewrite — bugs in code the pipeline will replace are deliberately not touched here.

This is a maintenance spec, not a feature spec. Mostly mechanical fixes with small design decisions where ambiguous.

## Scope decision: what's in vs out

The AI blend pipeline spec (`2026-05-04-ai-blend-pipeline-design.md`) will:
- Replace `src/api/src/routes/transcription.js` and `summarization.js` with `/v1/sessions/...` REST endpoints (no WebSocket)
- Migrate `imagePaths: [String]` to a `Photo` model with content-addressed filenames
- Introduce a new `AugmentedNoteView` rendering path

So the following bugs from the original repo scan are **out of scope here** because the AI-pipeline rewrite obviates them:
- Duplicate WebSocket message handlers (`transcription.js:199, :286`) — the WebSocket path goes away
- Stale-connection interval leak on shutdown (`transcription.js:343-363`) — same
- Unauthenticated WebSocket — REST endpoints will have auth middleware per the auth spec
- Image filename collision (`SimpleNoteDetailView.swift:583`) — content-addressed storage in the AI spec eliminates this

In scope:

| # | Bug | Location | Fix |
|---|---|---|---|
| 1 | `AVAudioRecorder` delegate mutates `@Observable` state off main actor | `AudioRecordingManager.swift:398-410` | Wrap mutations in `Task { @MainActor in ... }` |
| 2 | Incomplete `MainActor` refactor — still using `DispatchQueue.main.async` inside `Task {}` | `SimpleMainView.swift:202, :218` | Replace with `await MainActor.run { ... }` to match `NewNoteView.swift:527` |
| 3 | Stale `modelContext` after `dismiss()` then async `Task` | `NewNoteView.swift:502-513` | Capture context-needed work into a value type before dismiss; do persistence before `dismiss()`, or dispatch the save to a context held by the parent |
| 4 | Transcription re-trigger race in `.onAppear` | `SimpleNoteDetailView.swift:344-426` | Guard with an in-flight `Task` handle stored on the view model; cancel-or-skip if a transcription is already running for this note |
| 5 | CORS wildcard default | `src/api/src/config/index.js:28` | Remove `'*'` default; require explicit `CORS_ORIGIN`; fail-fast in production if unset |
| 6 | Deepgram key risk via init logs | `src/api/src/services/deepgramService.js:17-19` | Use a redacted-config logger; never log the full config object |

Not on the punch list but worth doing while we're here:
- Add a `contentHash` precomputation hook for photos — bridges into the AI spec's content-addressed storage. Defer to the AI spec implementation; do not duplicate here.

## Designs per fix

### #1 — `AudioRecordingManager` delegate main-actor isolation

`audioRecorderEncodeErrorDidOccur` is called by AVFoundation on an arbitrary thread. Today it directly mutates `@Observable` state. The sibling `audioRecorderDidFinishRecording` already wraps in `DispatchQueue.main.async`. Bring this one in line, and migrate both to structured concurrency to match the rest of the codebase:

```swift
nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    Task { @MainActor in
        self.state = .idle
        self.currentRecordingPath = nil
        self.lastError = error
    }
}
```

Same treatment for `audioRecorderDidFinishRecording`. Drop the `DispatchQueue.main.async` form.

### #2 — Complete the `MainActor` refactor

`SimpleMainView.swift:202` and `:218` are the holdouts from commit `334818b`. Replace `DispatchQueue.main.async { ... }` with `await MainActor.run { ... }` (since they're already inside `Task { ... }` blocks). No behavior change; consistency only.

### #3 — `modelContext` lifetime in `NewNoteView.saveNote()`

Today:
```swift
func saveNote() {
    Task {
        // uses self.modelContext
    }
    dismiss()
}
```

`dismiss()` tears down the view; the `Task` continues holding `self`. `modelContext` may be invalid by the time the Task accesses it.

Fix: do the save synchronously before dismiss, OR pass the work to the parent's context via a closure. Recommended: synchronous save (it's a SwiftData write to a local store — fast):

```swift
func saveNote() {
    do {
        try persist(in: modelContext)
        dismiss()
    } catch {
        showError(error)
    }
}
```

If any of the work is genuinely async (e.g. kicking off transcription), spawn that into a top-level `Task` from the parent before navigation, not from the view that's being dismissed.

### #4 — Transcription re-trigger race

`SimpleNoteDetailView.checkAndTriggerPendingTranscription()` runs on `.onAppear`. If the user closes and reopens the sheet while transcription is in flight, two `Task`s can run simultaneously and last-writer-wins on `modelContext.save()`.

Fix: store the in-flight task on a view-scoped state, and check it before starting a new one:

```swift
@State private var transcriptionTask: Task<Void, Never>?

func checkAndTriggerPendingTranscription() {
    guard transcriptionTask == nil else { return }
    guard note.transcriptionStatus == "pending" else { return }
    transcriptionTask = Task {
        defer { transcriptionTask = nil }
        await runTranscription()
    }
}
```

Note: this is a tactical fix. The AI pipeline spec replaces the `transcriptionStatus` field with a richer `blendStatus` and moves the orchestration server-side, which structurally eliminates the race. This fix is for the gap between now and that landing.

### #5 — CORS default

In `src/api/src/config/index.js`:

```js
// before
CORS_ORIGIN: Joi.string().default('*')

// after
CORS_ORIGIN: Joi.string().required().when('NODE_ENV', {
  is: 'production',
  then: Joi.string().required().disallow('*'),
  otherwise: Joi.string().default('http://localhost:3000')
})
```

Production startup fails fast if `CORS_ORIGIN` is missing or `'*'`. Dev defaults to localhost.

### #6 — Deepgram key logging risk

In `deepgramService.js:17-19` and the startup logs in `config/index.js:141-146`, audit any `console.log` or `logger.info` calls that take a config object. Replace with explicit field logging:

```js
// avoid
logger.info('Deepgram service initialized', config.deepgram);

// prefer
logger.info('Deepgram service initialized', {
  model: config.deepgram.model,
  language: config.deepgram.language,
});
```

Add a small `redactConfig(config)` helper that returns a clone with secrets stripped (`apiKey`, `token`, anything matching `/key|secret|token|password/i`), and use it whenever the full config is logged for debugging. Wire `redactConfig` into the existing Winston logger as a default formatter so future calls are protected too.

## Out of scope (already covered or deferred)

- Image filename collision → AI spec's `Photo` model with sha256 filenames
- WebSocket cleanup, auth, duplicate handlers → endpoints removed in AI spec
- Transcription orchestration redesign → AI spec moves this server-side
- All other bugs not on the punch list

## Acceptance criteria

- `xcodebuild` compiles cleanly with strict-concurrency warnings on (no main-actor isolation warnings in `AudioRecordingManager` or `SimpleMainView`)
- `npm run lint` passes with the new CORS Joi schema; `npm test` passes
- Smoke test: open a note while transcription is running, close the sheet, reopen it — only one transcription completes (verify via log scan or by adding a counter)
- Smoke test: start API with no `CORS_ORIGIN` set and `NODE_ENV=production` → server refuses to start with a clear error
- Grep audit: no `logger.info(.*config.*)` patterns that pass full config; `redactConfig` is the only path

## Sequencing

This spec ships independently and immediately. It does not block the AI pipeline spec from being designed in parallel, but it should land **before** the AI pipeline implementation so the new code isn't built on top of broken capture primitives.
