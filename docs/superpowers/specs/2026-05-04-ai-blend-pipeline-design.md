# AI Blend Pipeline — Design

Date: 2026-05-04
Status: Approved (pending user spec review)

## Summary

A post-hoc, one-shot pipeline that turns a recorded session (audio + photos + user-typed notes) into a single blended note. The user's typed notes are preserved verbatim; AI fills in around them using the audio transcript and what was on screen in each photo. Vision is in the loop — Claude reads the slides, not just the audio.

The pipeline is plumbed for a credit ledger from day one but enforces no cap in v1.

## Goals

1. Record-and-go capture: hit record, take pics, type sparse notes, hit stop, get a coherent blended note.
2. Voice + pics + notes are one product — not three parallel streams in the UI.
3. Pics carry their content (slide text, scene description) into the blend.
4. Cost is metered per session; v1 ships free/unlimited but the meter runs.

## Non-goals (v1)

- Folders, tags, conferences-as-entities
- Templates
- Chat-with-note
- Action-item / follow-up extraction
- Markdown export, share sheet
- Cross-note search or cross-note Q&A
- iCloud / cross-device sync
- Streaming AI output
- Real-time augmentation during recording
- Speaker diarization
- Calendar integration

These are tracked in the gap analysis (`2026-05-04-granola-gap-analysis.md`) for future consideration.

## Architecture

### Inputs (per session)

| Input | Source | Notes |
|---|---|---|
| Audio file | `AudioRecordingManager` | Already implemented |
| Photos `[Photo]` | In-app camera or photo library | Each photo carries a `capturedAt: Date` timestamp |
| User notes | `userNotes: String` field | Free-form; no per-paragraph timing tracked in v1 |

### Pipeline (triggered on Stop)

```
Stop tapped
  └─ Transcribe (Deepgram nova-3)            → transcript + word timings
  └─ Per-image extract (Haiku 4.5, parallel) → { ocrText, description } per image
  └─ Blend (Sonnet 4.6, single call)         → blendedMarkdown
  └─ Persist + render
```

Each stage is independently retryable. Cached outputs (transcript, per-image extracts) are reused on regenerate.

### Models

- **Transcription**: Deepgram `nova-3` (already integrated). Returns full text and word-level timestamps.
- **Per-image extraction**: Anthropic `claude-haiku-4-5-20251001`. One call per image, in parallel. Output: `{ ocrText: String, description: String }`. Cached by image content hash (sha256 of image bytes).
- **Blend**: Anthropic `claude-sonnet-4-6`. Single call. Inputs: full transcript text, list of image extracts with timestamps, user notes verbatim. Output: structured JSON (see below).

Why this split: the per-image pass is cheap and parallel; the blend is one careful call with the long context. Caching per-image lets regenerate skip the vision spend if photos didn't change.

### Output schema

The blend returns JSON conforming to:

```
{
  "blendedMarkdown": String,    // The final note body — plain markdown, no custom tags
  "userNoteSpans": [            // Char ranges in blendedMarkdown that came from the user verbatim
    { "start": Int, "end": Int }
  ],
  "quoteSpans": [               // Verbatim transcript quotes embedded in the blend
    { "start": Int, "end": Int, "transcriptStart": Float, "transcriptEnd": Float, "speaker": String? }
  ],
  "imagePlacements": [          // Where photos drop into the markdown
    { "imageId": String, "charOffset": Int }   // insert at this char offset
  ],
  "citations": [                // AI-claim provenance back to transcript word ranges
    { "blendStart": Int, "blendEnd": Int, "transcriptStart": Float, "transcriptEnd": Float }
  ]
}
```

The markdown body contains no custom tags or sentinels — it is real, valid markdown. All structural metadata (which spans are user-verbatim, which are quotes, where images go, which spans cite which transcript ranges) lives in the parallel arrays above. The renderer is the single consumer of these arrays and applies styling/insertions on top of the parsed markdown.

#### Rules enforced via prompt

- User notes appear verbatim somewhere in `blendedMarkdown`, with their char ranges reported in `userNoteSpans`.
- AI prose fills in around them.
- Speaker quotes must be exact transcript text and reported in `quoteSpans`.
- Photos are placed via `imagePlacements` at char offsets the AI chose based on what was being discussed at the photo's `capturedAt` timestamp.
- The AI never invents quotes or facts beyond the transcript.

### Persistence (SwiftData)

Add to existing `Note`:

```swift
@Model final class Note {
  // ... existing fields ...

  var transcript: String?              // Full transcript text
  var transcriptWordsJSON: Data?       // JSON-encoded [Word(text, start, end)]
  var blendedMarkdown: String?         // Final blended output with sentinels
  var blendCitationsJSON: Data?        // JSON-encoded citations + image placements + user spans
  var blendStatus: BlendStatus         // .pending, .transcribing, .extracting, .blending, .complete, .failed
  var blendError: String?
  var blendCostMicros: Int?            // Cost of this blend in millionths of a USD, plumbed for credits
  var blendModelVersion: String?       // e.g. "sonnet-4-6+haiku-4-5+nova-3" — invalidates cache on change
}
```

Photos already exist as `imagePaths: [String]`. Add:

```swift
@Model final class Photo {
  var localPath: String                // file URL on disk
  var contentHash: String              // sha256 of bytes; doubles as cache key
  var capturedAt: Date
  var ocrText: String?
  var description: String?
  var extractStatus: ExtractStatus     // .pending, .complete, .failed
  var note: Note?
}
```

Migrating from `imagePaths: [String]` to a `Photo` relationship: lightweight migration, paths become rows, `capturedAt` defaulted to `note.createdAt`, `contentHash` computed on first load.

Image files are stored content-addressed: filename = `{sha256}.jpg`. Solves the timestamp-collision bug from the earlier scan and gives free deduplication.

### Rendering (SwiftUI)

`AugmentedNoteView` parses `blendedMarkdown` and overlays metadata from the parallel arrays:

- Default: AI text (gray/secondary color, tappable on a `citations`-covered range to show transcript provenance)
- Char ranges in `userNoteSpans` → primary color, normal weight
- Char ranges in `quoteSpans` → indented italic block with timestamp badge, tap to play audio at `transcriptStart`
- Char offsets in `imagePlacements` → inline thumbnail with caption "Slide: {photo.ocrText[:80]}", tap to fullscreen

Implementation: build an `AttributedString` by walking `blendedMarkdown`, applying attributes from the span arrays, and splitting at `imagePlacements` offsets to inject thumbnail views. Render as a `LazyVStack` of paragraph chunks (so tappability works per-paragraph).

### Credit model (plumbed, not enforced)

- **Cost computation** runs after every successful blend and is recorded on the `Note` (`blendCostMicros`).
- **Cost formula** (USD micros):
  - Deepgram: `seconds × $0.0043 / 60 = seconds × 71.7 micros/sec`
  - Haiku per image: flat ~`5000 micros` (≈ $0.005)
  - Sonnet blend: `(input_tokens × 3 + output_tokens × 15) micros / 1000`
- **Credit conversion** (rule-of-thumb for v1 UI display only): `1 credit = 30 minutes of audio + 5 images`. Translates to roughly:
  - 30 min × 71.7 µ/s × 60 = 129,060 µ Deepgram
  - 5 × 5,000 µ = 25,000 µ Haiku
  - ~50,000 µ Sonnet (8K input, 2K output)
  - **≈ 200,000 micros = $0.20 ≈ 1 credit**
- v1 behavior: log cost, no balance check, no debit. The infrastructure (account, balance field, debit endpoint) is wired up so flipping enforcement on later is a config flag.

### Failure modes

| Stage | Failure | Behavior |
|---|---|---|
| Deepgram | Network/API error | `blendStatus = .failed`, retry button visible, no cost recorded |
| Image extract (any one) | API error or invalid image | That photo's `extractStatus = .failed`, others continue, blend proceeds with whatever extracts succeeded |
| Sonnet blend | API error or invalid JSON | `blendStatus = .failed` with `blendError`, retry button visible, transcript and image extracts persisted, no Sonnet cost recorded (Deepgram + Haiku costs are still recorded since they completed) |
| Validation (output JSON malformed) | Schema mismatch | Single retry with stricter prompt; if second attempt fails, mark `.failed` |

Regenerate behavior: skip stages whose inputs haven't changed (transcript and per-image extracts are cached by audio file hash and image content hash). The Sonnet blend always runs and is always charged — there is no free regenerate. If the user added a photo, the new photo's extract runs + the blend, both charged. If the user only edited notes, only the blend runs, charged at full rate.

### Backend changes (`src/api`)

New endpoints, replacing/augmenting the current `transcription` and `summarization` routes:

- `POST /v1/sessions` → create a session record, returns `sessionId`
- `POST /v1/sessions/:id/audio` → upload audio, kicks off Deepgram, returns transcript when ready (or job id for polling)
- `POST /v1/sessions/:id/photos` → upload one photo (multipart), kicks off Haiku extract
- `POST /v1/sessions/:id/blend` → run Sonnet blend with transcript + extracts + user notes (sent in body), returns blended JSON
- `GET /v1/sessions/:id` → fetch session state for resume
- `GET /v1/account/balance` → returns `{ creditsAvailable: Int, creditsUsedThisSession: Int }` (v1: returns `Int.max` for `creditsAvailable`)

Auth, accounts, and the actual ledger are out of scope for this spec — see auth and credit-ledger specs. For now, requests are accepted with no auth and `userId` is fixed to `"local-dev"`. Endpoints are shaped so adding auth is a middleware change, not a route rewrite.

### Prompt (Sonnet blend) — sketch

```
You are blending a transcript, photos with extracted text, and the user's typed
notes into a single coherent set of session notes.

Rules:
1. Preserve the user's notes verbatim somewhere in the output.
2. Around the user's notes, write AI prose that fills in context from the transcript.
3. Output plain markdown — NO custom tags, NO sentinels. Just real markdown.
4. Track structure with parallel arrays in the JSON output:
   - userNoteSpans: char ranges in blendedMarkdown where user-verbatim text appears
   - quoteSpans: char ranges of speaker quotes (must be exact transcript text), with their transcript timestamps
   - imagePlacements: char offsets where each photo should be inserted
   - citations: char ranges of AI claims with the transcript range they're grounded in
5. Place each photo near the moment its content was being discussed (use the photo's capturedAt).
6. Output JSON exactly matching this schema: { blendedMarkdown, userNoteSpans, quoteSpans, imagePlacements, citations }.
7. Do not invent. If the transcript is silent on something the user noted, leave the
   user note as-is without expansion. Do not fabricate speaker quotes.

INPUTS:
USER NOTES:
{userNotes}

TRANSCRIPT (with word timestamps):
{transcript}

PHOTOS:
[{ id, capturedAt, ocrText, description }, ...]
```

The prompt is iterated outside the spec. The contract (input shape, output shape) is what's load-bearing.

## Migration / sequencing

This spec depends on the capture loop being stable. Sequencing:

1. **Capture-loop hardening** (separate spec, next) — fix the bugs from the earlier repo scan: transcription race, MainActor inconsistency, image filename collision, modelContext lifetime, WebSocket auth, CORS default. None block this spec from being designed but they block it from shipping cleanly.
2. **AI blend pipeline** (this spec) — implementation plan to follow.
3. **Auth + account model** (separate spec) — required before credit enforcement.
4. **Credit ledger + metering** (separate spec) — flips this spec's credit plumbing from observe-only to enforce.
5. **StoreKit IAP** (separate spec) — last.

## Open questions

None blocking. Deferred:

- Whether to track typing time per paragraph for true chronological weaving of user notes into the blend. v1 hands the AI all user notes as one block and trusts the AI to place them. Revisit if placement is consistently wrong.
- Whether to expose a "credits this session" UI element in v1 even though there's no cap. Probably yes — bakes the user's mental model early.
- (resolved) Regenerate is always charged at full blend rate. Cached transcript/image extracts avoid re-paying those stages, but the Sonnet blend always runs and always debits.

## Acceptance criteria

A working v1:

- Record audio, take 3 photos, type sparse notes, tap Stop.
- Within ~20s of Stop, see an `AugmentedNoteView` showing user notes (primary color) interleaved with AI prose (gray), photos placed inline, occasional speaker quotes with timestamp badges.
- Tap a quote → audio jumps to that timestamp.
- Tap an AI prose paragraph → citation sheet shows the transcript span it's grounded in.
- `blendCostMicros` is populated and visible somewhere (debug screen acceptable for v1).
- Regenerate after adding a photo runs only the new image extract + blend, not Deepgram.
- All failure modes leave the user with a recoverable state (retry button, no double-charged costs).
