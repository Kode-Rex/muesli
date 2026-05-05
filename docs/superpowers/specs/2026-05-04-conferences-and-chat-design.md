# Conferences + Chat — Design

Date: 2026-05-04
Status: Draft (pending user review)

## Summary

Two scope additions in one spec because they're tied:

1. **`Conference`** as a first-class SwiftData entity. Notes belong to a conference. Replaces the free-text `conferenceName` field with a real relationship.
2. **Chat** at two levels: chat with one talk (single Note), chat across a whole conference (all Notes in a Conference). Uses Claude Sonnet with full-context prompting; long conferences trigger a Haiku-driven compression pass to fit within the model window. No RAG, no embeddings, no vector store.

The chat conversation is persisted per-scope (per-talk and per-conference), so users can come back to a thread and continue.

## Goals

1. A conference grouping that lets the user browse notes by event, not just by date.
2. Ask one talk a question — get a grounded answer fast.
3. Ask the conference a question — get a synthesized answer across all attended talks.
4. Conversations persist locally (SwiftData) and remotely (server, scoped to user).
5. Cost is transparent — every chat turn debits the credit ledger and is shown in the UI.
6. Long conferences degrade gracefully via compression, not error.

## Non-goals

- Embeddings, vector store, RAG plumbing
- Cross-conference Q&A ("what came up about LLM evals across all my conferences?") — defer to v2
- Sharing chat threads between users
- Web search or external sources in chat — chat sees only the user's notes
- Voice chat input (defer)
- Image attachment in chat input — chat queries are text-only; images are already in the notes the chat sees

## Architecture

### Data model — Conferences

Add a new `@Model`:

```swift
@Model final class Conference {
  var id: UUID
  var name: String                  // "DataSummit 2026"
  var startDate: Date?              // optional — many users won't bother
  var endDate: Date?
  var location: String?
  var createdAt: Date
  @Relationship(deleteRule: .cascade, inverse: \Note.conference) var notes: [Note]
  @Relationship(deleteRule: .cascade) var chatThreads: [ChatThread]
}
```

Modify `Note`:

```swift
@Model final class Note {
  // ... existing fields ...
  var conference: Conference?       // optional: notes can be unfiled
  @Relationship(deleteRule: .cascade) var chatThreads: [ChatThread]
}
```

The `conferenceName: String` field on `Note` is migrated: a one-shot migration creates a `Conference` for each distinct existing value and links each `Note` to its `Conference`. Empty/nil conferenceName → `Note.conference = nil`.

### Data model — Chat

```swift
@Model final class ChatThread {
  var id: UUID
  var scope: ChatScope              // .talk(noteId) or .conference(conferenceId)
  var title: String                 // auto-named from first user message
  var createdAt: Date
  var updatedAt: Date
  var note: Note?                   // populated if scope == .talk
  var conference: Conference?       // populated if scope == .conference
  @Relationship(deleteRule: .cascade) var messages: [ChatMessage]
}

enum ChatScope: Codable { case talk, conference }   // discriminator only; the relationship tells you which

@Model final class ChatMessage {
  var id: UUID
  var role: ChatRole                // .user or .assistant
  var content: String               // markdown
  var createdAt: Date
  var costMicros: Int?              // populated on assistant messages; user messages free
  var citationsJSON: Data?          // optional: which Notes / which transcript spans the answer cited
}

enum ChatRole: String, Codable { case user, assistant }
```

Each Note can have its own thread(s); each Conference can too. Multiple threads per scope is fine — users may want to start fresh.

### Chat data flow

```
User asks question in scope (talk | conference)
  ├─ assemble context for scope (next section)
  ├─ append user message to thread
  ├─ POST /v1/chat with { threadId, scope, scopeId, message, history }
  ├─ server:
  │   ├─ fetch context (from blended notes belonging to the scope)
  │   ├─ if total tokens > THRESHOLD: compress (Haiku per-note → digest)
  │   ├─ stream Sonnet completion with [system, history..., user]
  │   ├─ on completion: compute cost, debit ledger
  │   └─ return assistant message + citations
  ├─ append assistant message to thread
  └─ render in chat UI
```

### Context assembly

For **talk scope**:
- The Note's `blendedMarkdown` (~2-4K tokens typical)
- The Note's raw transcript if total budget allows (~4-10K tokens for a 45-min talk)
- The user's typed notes (already inside `blendedMarkdown`)
- Photo extracts (already inside `blendedMarkdown`)
- Recent conversation history (last 10 turns)

Total typical: 6-15K tokens. Fits comfortably in Sonnet's 200K window. No compression needed.

For **conference scope**:
- Each Note's `blendedMarkdown` for every Note in the Conference
- The Conference's metadata (name, dates, location)
- Recent conversation history (last 10 turns)

Total typical: 30-talk conference × 3K tokens ≈ 90K. Fits Sonnet directly.

If total > **120K tokens** (the THRESHOLD): trigger compression.

### Compression (long conferences only)

Each Note in the Conference is summarized by Haiku 4.5 into a "talk digest" of ~1-2K tokens. Cached per-Note by content hash so subsequent chat turns don't re-pay. The conference chat then sees `[talk_digest_1, talk_digest_2, ...]` instead of `[blended_markdown_1, ...]`.

Talk digest schema (Haiku output):

```json
{
  "title": "...",
  "speaker": "...",
  "duration": "47 min",
  "key_claims": ["...", "...", "..."],
  "demos_or_slides": ["...", "..."],
  "memorable_quotes": [{ "quote": "...", "ts": 754 }],
  "user_emphasis": "what the user typed verbatim, condensed"
}
```

Stored on `Note.talkDigestJSON: Data?`. Recomputed when `Note.blendModelVersion` changes.

Compression cost is its own ledger entry (`reason: 'compress_for_chat'`), debited the first time a Conference exceeds threshold and again whenever a Note in the Conference is re-blended after.

### Citations

The Sonnet prompt requires the model to return citations:

```json
{
  "answer": "Sarah Chen argued that eval suites must be versioned alongside models...",
  "citations": [
    { "noteId": "...", "transcriptStart": 754.2, "transcriptEnd": 758.4 },
    { "noteId": "...", "section": "user_notes" }
  ]
}
```

In the talk-scope chat, citations include transcript timestamps for the current note → tap a citation, the audio player jumps. In the conference-scope chat, citations include the Note id → tap a citation, navigate into the talk's augmented note view scrolled to the cited region.

### Backend routes

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| POST | `/v1/chat/threads` | required | `{ scope: "talk"|"conference", scopeId: UUID }` | `{ threadId }` |
| POST | `/v1/chat/threads/:id/messages` | required | `{ message: String, stream: Bool }` | SSE stream of tokens, then `{ messageId, costMicros, citations }` |
| GET | `/v1/chat/threads/:id` | required | — | full thread for restore |
| GET | `/v1/chat/threads?scope=&scopeId=` | required | — | list of threads for that scope |
| DELETE | `/v1/chat/threads/:id` | required | — | 204 |

Streaming: Server-Sent Events. iOS reads with `URLSession.bytes(for:)` and parses the SSE wire format. Token delta arrives as `data: {"text": "Sarah"}` chunks; final completion as `data: {"final": {...}}`.

### Cost computation

Per chat turn:

```js
function chatCostMicros({ contextTokens, historyTokens, outputTokens, compressionTokensIn, compressionTokensOut }) {
  // Sonnet 4.6 main answer
  const sonnet = Math.ceil(((contextTokens + historyTokens) * 3 + outputTokens * 15) / 1_000);
  // Haiku compression (only when triggered, per note compressed)
  const haiku = Math.ceil((compressionTokensIn * 0.8 + compressionTokensOut * 4) / 1_000);
  return sonnet + haiku;
}
```

Typical talk-scope chat turn: ~50K micros (~$0.05, ~0.25 credits). Conference-scope chat turn (no compression): ~150K micros (~$0.15, ~0.75 credits). Conference-scope with compression on first turn: ~600K micros (one-time, then cached → subsequent turns drop to ~150K).

UI shows per-turn cost ("this answer ≈ 0.5 credits") so users learn the unit economics.

### iOS UI

Two entry points:

1. **From the augmented note view (Scene 6)**: a "Chat about this talk" button in the `⋯` menu. Opens a sheet with the chat UI scoped to the Note.
2. **From the conference detail view (new — see below)**: a "Chat with this conference" button in the conference header. Opens a sheet scoped to the Conference.

#### Conference detail view (new screen)

Tap a conference name from a Note row → push to ConferenceDetailView:
- Header: conference name (Fraunces display), dates, talk count
- "Chat with this conference" button (accent, prominent)
- List of Notes belonging to the Conference, same row design as NotesListView

#### Chat sheet UI

- Top: thread title (auto-set after first message), close button
- Middle: scrolling message list. User messages right-aligned in `--paper-raise`; assistant messages left-aligned in `--screen` with serif body
- Citations under each assistant message render as small chips ("Sarah Chen 12:34" or "Talk: Eval as engineering"); tap → navigate into the note (talk scope) or note + scroll-to (conference scope)
- Bottom: input field (Manrope), send button (accent, disabled when empty), small per-turn cost preview ("this answer will cost ≈ 0.3 credits")
- Streaming: assistant message renders character-by-character as tokens arrive; cost line populates after final delta

### Failure modes

| Failure | Behavior |
|---|---|
| Network drops mid-stream | Partial response saved as `messageStatus: .interrupted`, "Continue" button to re-send the same prompt |
| Sonnet returns invalid citation JSON | Strip citations, render answer as plain text, log warn — never fail the turn over citation parsing |
| Compression fails for a note | Use that note's `blendedMarkdown` directly (skip compression for that one note); proceed |
| Total context still exceeds window after compression | Refuse turn with `413 conference_too_large`, surface "This conference is too big to chat with right now — try chatting with individual talks." Defer the proper fix (cross-talk RAG) to v2 |
| User exhausts credits mid-turn | The estimate-before-send check prevents starting; mid-turn exhaustion can't happen since cost is computed after completion |

### Privacy / data scope

- Chat threads are scoped to the user's account (auth required on every endpoint)
- Threads are deleted when the parent Note or Conference is deleted (cascade)
- Talk digests are derived data; deleted with the Note
- Server stores chat history; client also caches it locally for offline reading. New turns require online (LLM call)

## Migration

Migration steps when this lands:

1. Add `Conference`, `ChatThread`, `ChatMessage` SwiftData models. Lightweight migration creates the tables; existing notes are unfiled (`conference == nil`).
2. One-shot migration in `MuesliApp.init`: read every Note's existing `conferenceName`, group by name, create a `Conference` per distinct value (case-insensitive trim), link Notes. Run once gated on a `UserDefaults` flag.
3. Add `talkDigestJSON: Data?` to Note model.
4. Add new backend tables: `conferences`, `chat_threads`, `chat_messages`. Postgres migration.
5. Add `/v1/chat/*` endpoints behind the existing auth middleware.
6. Add chat UI to AugmentedNoteView (`⋯` menu entry) and the new ConferenceDetailView.
7. Add Conference list/management UI: a "Conferences" tab next to "Notes" on the home screen, OR an inline "Group by conference" toggle on the existing notes list. Decide during implementation; my recommendation is the toggle (simpler, no new top-level tab).

## Sequencing relative to other specs

This depends on:
- AI pipeline spec (provides `blendedMarkdown` — without it, no chat context)
- Auth spec (chat is per-user)
- Credit ledger spec (chat debits per turn)

Build order:
1. AI pipeline (prerequisite)
2. Auth (prerequisite)
3. Credit ledger (prerequisite)
4. **This spec** — Conferences + chat
5. StoreKit IAP (independent, can run in parallel with this)

## Acceptance criteria

- Create a Note → it can optionally be assigned to a Conference (via picker on save sheet, with "+ New conference" inline)
- Existing Notes with a `conferenceName` value are auto-migrated into Conferences on first launch after upgrade
- Tap a conference name from any Note row → ConferenceDetailView shows that Conference's metadata and its Notes
- From the AugmentedNoteView, "Chat about this talk" opens a chat sheet scoped to the Note. Ask a question → answer streams in within a few seconds, with citations chipped underneath
- From ConferenceDetailView, "Chat with this conference" opens a chat sheet scoped to the Conference. Ask "what came up about RAG across these talks?" → synthesized answer with citations to specific Notes
- A 60-talk conference triggers compression: first chat turn is slower (Haiku passes), subsequent turns are normal latency
- Per-turn cost is shown before send (estimate) and after (actual). Both round to 0.1-credit precision in display
- Network drop mid-stream leaves a partial-message indicator; Continue resumes
- All chat data deletes when the parent Note/Conference is deleted

## Open questions

- (resolved) Compression strategy: Haiku per-note digest cached on Note, regenerated on `blendModelVersion` change
- (resolved) Cross-conference chat: deferred to v2
- (resolved) Vector store / embeddings: not in v1
- Whether to gate "Chat with conference" behind a minimum talk count (e.g. ≥ 2 talks before the button appears) — recommend yes (1-talk conference chat is just talk chat)
- Whether to expose chat thread browsing UI ("show me all threads about a topic") — defer; v1 surfaces threads from their parent screen only
- Streaming format: SSE vs WebSocket — recommend SSE for v1 (simpler, one-way is fine, no upgrade handshake)
- Where to put the "Group by conference" toggle on the home screen — recommend: top of NotesListView, small text button next to "Conference notes · N sessions" — toggles between flat date-sorted list and conference-grouped sections
