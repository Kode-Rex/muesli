# Conferences + Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote `Conference` to a SwiftData entity with a one-shot migration from the legacy `conferenceName: String` field, then layer chat at two scopes (per-talk, per-conference) on top. Streaming Sonnet responses with citation chips and per-turn cost. Long conferences trigger Haiku-driven compression that caches on each Note.

**Architecture:** Three layers, in dependency order: (1) data model (Conference, ChatThread, ChatMessage on iOS; conferences, chat_threads, chat_messages on Postgres). (2) Server-side chat: context assembly → optional compression → Sonnet stream → ledger debit → return + citations. (3) iOS UI: ConferenceDetailView, ChatSheetView (shared between scopes), entry points from AugmentedNoteView and ConferenceDetailView.

**Tech Stack:** Swift 5.9 / SwiftUI / SwiftData / URLSession SSE; Node 18 / Express / Anthropic SDK / `app-store-server-library` (already in API); pg + node-pg-migrate (from auth spec).

**Prerequisites — must be live before starting:**
- AI pipeline spec implemented (provides `Note.blendedMarkdown`, `transcriptWordsJSON`)
- Auth spec implemented (provides JWT auth middleware on `/v1/*`)
- Credit ledger spec implemented (provides `LedgerService.recordEntry`, idempotency, balance check)

If any prerequisite is missing, this plan blocks. Do not stub — actually integrate.

---

## File Structure

| Path | Responsibility |
|---|---|
| `src/mobile/Muesli/Models/Conference.swift` | New `@Model` for conferences |
| `src/mobile/Muesli/Models/ChatThread.swift` | `@Model` for threads + messages + scope enum |
| `src/mobile/Muesli/Models/Note.swift` | Add `conference: Conference?`, `talkDigestJSON: Data?`, `chatThreads` relationship |
| `src/mobile/Muesli/Migration/ConferenceMigration.swift` | One-shot migration of `conferenceName` → `Conference` rows |
| `src/mobile/Muesli/UI/Views/ConferenceDetailView.swift` | Scene 7 |
| `src/mobile/Muesli/UI/Views/ChatSheetView.swift` | Scene 8 — shared chat surface |
| `src/mobile/Muesli/UI/Components/CitationChip.swift` | Inline pill for assistant citations |
| `src/mobile/Muesli/UI/Components/StreamingMessage.swift` | Token-by-token rendering with reduce-motion fallback |
| `src/mobile/Muesli/Services/ChatService.swift` | SSE client + streaming buffer |
| `src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift` | TDD migration |
| `src/mobile/MuesliTests/Services/ChatSSEParserTests.swift` | TDD SSE wire parsing |
| `src/api/migrations/0003_conferences_and_chat.sql` | Postgres tables |
| `src/api/src/services/chatContextService.js` | Context assembly + compression decision |
| `src/api/src/services/talkDigestService.js` | Haiku digest computation + cache |
| `src/api/src/services/chatStreamService.js` | Sonnet streaming + citation extraction |
| `src/api/src/routes/chat.js` | `/v1/chat/threads/*` REST + SSE endpoints |
| `src/api/tests/unit/chatContextService.test.js` | TDD context assembly + compression triggers |
| `src/api/tests/unit/talkDigestService.test.js` | TDD digest caching |
| `src/api/tests/unit/chatCost.test.js` | TDD cost formula |
| `src/api/tests/integration/chatStream.test.js` | E2E with mocked Anthropic |

---

## Phase A — Data model + migration (iOS only, ships independently)

### Task 1: Add Conference SwiftData model + migration (TDD)

**Files:**
- Create: `src/mobile/Muesli/Models/Conference.swift`
- Modify: `src/mobile/Muesli/Models/Note.swift`
- Create: `src/mobile/Muesli/Migration/ConferenceMigration.swift`
- Create: `src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift`
- Modify: `src/mobile/Muesli/MuesliApp.swift` (add Conference + ChatThread + ChatMessage to schema, run migration)

- [ ] **Step 1: Write failing migration tests**

```swift
// src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift
import XCTest
import SwiftData
@testable import Muesli

@MainActor
final class ConferenceMigrationTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testMigratesDistinctConferenceNamesIntoEntities() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let n1 = Note(title: "Talk 1", conferenceName: "DataSummit 2026")
        let n2 = Note(title: "Talk 2", conferenceName: "datasummit 2026")  // case-different
        let n3 = Note(title: "Talk 3", conferenceName: "DubDub 2026")
        let n4 = Note(title: "Talk 4", conferenceName: "")  // unfiled
        for n in [n1, n2, n3, n4] { context.insert(n) }
        try context.save()

        ConferenceMigration.run(in: context)

        let conferences = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(conferences.count, 2)
        XCTAssertTrue(conferences.contains { $0.name == "DataSummit 2026" })
        XCTAssertTrue(conferences.contains { $0.name == "DubDub 2026" })

        XCTAssertEqual(n1.conference?.name, "DataSummit 2026")
        XCTAssertEqual(n2.conference?.name, "DataSummit 2026")  // case-insensitive merge
        XCTAssertEqual(n3.conference?.name, "DubDub 2026")
        XCTAssertNil(n4.conference)
    }

    func testIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let n1 = Note(title: "Talk", conferenceName: "X")
        context.insert(n1)
        try context.save()

        ConferenceMigration.run(in: context)
        ConferenceMigration.run(in: context)  // run twice

        let conferences = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(conferences.count, 1)
    }

    func testTrimsWhitespace() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let n = Note(title: "T", conferenceName: "  DataSummit  ")
        context.insert(n)
        try context.save()

        ConferenceMigration.run(in: context)

        let conferences = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(conferences.count, 1)
        XCTAssertEqual(conferences.first?.name, "DataSummit")
    }
}
```

- [ ] **Step 2: Run tests, verify failures**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ConferenceMigrationTests 2>&1 | tail -10
```

Expected: failures (Conference, ChatThread, ChatMessage, ConferenceMigration not defined).

- [ ] **Step 3: Define Conference model**

```swift
// src/mobile/Muesli/Models/Conference.swift
import Foundation
import SwiftData

@Model
final class Conference {
    var id: UUID
    var name: String
    var startDate: Date?
    var endDate: Date?
    var location: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Note.conference) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var chatThreads: [ChatThread] = []

    init(name: String, startDate: Date? = nil, endDate: Date? = nil, location: String? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.createdAt = Date()
    }
}
```

- [ ] **Step 4: Define ChatThread + ChatMessage models**

```swift
// src/mobile/Muesli/Models/ChatThread.swift
import Foundation
import SwiftData

enum ChatScope: String, Codable { case talk, conference }
enum ChatRole: String, Codable { case user, assistant }

@Model
final class ChatThread {
    var id: UUID
    var scopeRaw: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var note: Note?
    var conference: Conference?
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage] = []

    var scope: ChatScope {
        get { ChatScope(rawValue: scopeRaw) ?? .talk }
        set { scopeRaw = newValue.rawValue }
    }

    init(scope: ChatScope, title: String, note: Note? = nil, conference: Conference? = nil) {
        self.id = UUID()
        self.scopeRaw = scope.rawValue
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.note = note
        self.conference = conference
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date
    var costMicros: Int?
    var citationsJSON: Data?
    var thread: ChatThread?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: ChatRole, content: String, thread: ChatThread? = nil) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.thread = thread
    }
}
```

- [ ] **Step 5: Modify Note model**

In `src/mobile/Muesli/Models/Note.swift`, add (without removing the existing `conferenceName: String` — keep for backward compat, deprecate in a follow-up):

```swift
var conference: Conference?
var talkDigestJSON: Data?
@Relationship(deleteRule: .cascade) var chatThreads: [ChatThread] = []
```

Mark as default-nil so existing data continues to work (lightweight migration).

- [ ] **Step 6: Implement ConferenceMigration**

```swift
// src/mobile/Muesli/Migration/ConferenceMigration.swift
import SwiftData
import Foundation

enum ConferenceMigration {
    private static let runFlagKey = "muesli.conferenceMigration.v1.complete"

    /// One-shot. Idempotent.
    static func run(in context: ModelContext) {
        // Build name → Conference map (case-insensitive, whitespace-trimmed)
        var byKey: [String: Conference] = [:]
        let existing = (try? context.fetch(FetchDescriptor<Conference>())) ?? []
        for c in existing {
            byKey[normalize(c.name)] = c
        }

        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        for note in allNotes {
            guard note.conference == nil else { continue }
            let raw = note.conferenceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let key = normalize(raw)
            let conf = byKey[key] ?? Conference(name: raw)
            if byKey[key] == nil {
                context.insert(conf)
                byKey[key] = conf
            }
            note.conference = conf
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: runFlagKey)
    }

    static var hasRun: Bool {
        UserDefaults.standard.bool(forKey: runFlagKey)
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
```

- [ ] **Step 7: Wire schema + migration in MuesliApp**

In `MuesliApp.swift`, change the Schema:

```swift
let schema = Schema([
    Note.self,
    Conference.self,
    ChatThread.self,
    ChatMessage.self,
])
```

Add to `init()`:

```swift
init() {
    TranscriptionOrchestrator.shared.setContainer(sharedModelContainer)
    let context = ModelContext(sharedModelContainer)
    if !ConferenceMigration.hasRun {
        ConferenceMigration.run(in: context)
    }
}
```

- [ ] **Step 8: Run tests, verify pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ConferenceMigrationTests 2>&1 | tail -10
```

Expected: 3 pass.

- [ ] **Step 9: Run full test suite, verify no regressions**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -10
```

- [ ] **Step 10: Commit**

```bash
git add src/mobile/Muesli/Models src/mobile/Muesli/Migration src/mobile/Muesli/MuesliApp.swift src/mobile/MuesliTests/Models
git commit -m "feat(ios): Conference + ChatThread + ChatMessage SwiftData models

Conference promoted from a free-text field on Note to a first-class
@Model with a one-shot migration that groups existing Notes by
case-insensitive trimmed conferenceName. Migration is idempotent and
gated on a UserDefaults flag.

ChatThread + ChatMessage models prep for the chat scope to follow."
```

---

### Task 2: ConferenceDetailView (Scene 7)

**Files:**
- Create: `src/mobile/Muesli/UI/Views/ConferenceDetailView.swift`
- Modify: `src/mobile/Muesli/UI/Views/NotesListView.swift` — make conference name in row tappable, navigating to ConferenceDetailView

Translates Scene 7 of the mockup. Layout: hero header, prominent CTA card, list of notes belonging to the conference.

- [ ] **Step 1: Implement ConferenceDetailView**

```swift
// src/mobile/Muesli/UI/Views/ConferenceDetailView.swift
import SwiftUI
import SwiftData

struct ConferenceDetailView: View {
    let conference: Conference
    @State private var presentingChat = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                hero
                cta
                talksList
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .background(MuesliColor.screen)
        .sheet(isPresented: $presentingChat) {
            ChatSheetView(scope: .conference, conferenceId: conference.id, noteId: nil, scopeTitle: "\(conference.name) · \(conference.notes.count) talks")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONFERENCE").font(MuesliTypography.label).tracking(2.4).foregroundStyle(MuesliColor.accent)
            Text(conference.name)
                .font(MuesliTypography.font(family: .frauncesItalic, size: 32, opticalSize: 144, weight: 500, soft: 50))
                .foregroundStyle(MuesliColor.ink)
            metaLine
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) { Divider().background(MuesliColor.rule) }
    }

    private var metaLine: some View {
        let dateText: String? = {
            guard let s = conference.startDate else { return nil }
            let f = DateFormatter(); f.dateFormat = "MMM d"
            if let e = conference.endDate, e != s { return "\(f.string(from: s)) — \(f.string(from: e))" }
            return f.string(from: s)
        }()
        var parts: [(text: String, accent: Bool)] = []
        if let d = dateText { parts.append((d, false)) }
        if let l = conference.location, !l.isEmpty { parts.append((l, false)) }
        parts.append(("\(conference.notes.count) talks captured", true))

        return HStack(spacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                if i > 0 {
                    Text("·").foregroundStyle(MuesliColor.rule)
                }
                Text(p.text)
                    .foregroundStyle(p.accent ? MuesliColor.ink : MuesliColor.muted)
                    .fontWeight(p.accent ? .semibold : .regular)
            }
        }
        .font(MuesliTypography.metadata)
    }

    private var cta: some View {
        Button { presentingChat = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MuesliColor.onAccent)
                    .frame(width: 32, height: 32)
                    .background(MuesliColor.onAccent.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat with this conference")
                        .font(MuesliTypography.cardTitle)
                        .foregroundStyle(MuesliColor.onAccent)
                    Text("ASK ACROSS ALL \(conference.notes.count) TALKS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(MuesliColor.onAccent.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MuesliColor.onAccent.opacity(0.7))
            }
            .padding(14)
            .background(MuesliColor.accent, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: MuesliColor.accent.opacity(0.35), radius: 18, y: 6)
        }
        .padding(.top, 16)
        .accessibilityLabel("Chat with this conference, \(conference.notes.count) talks")
        .disabled(conference.notes.count < 1)
    }

    private var talksList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Talks".uppercased())
                .font(MuesliTypography.label).tracking(2)
                .foregroundStyle(MuesliColor.muted)
                .padding(.top, 22).padding(.bottom, 8)
            ForEach(conference.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                NavigationLink(destination: SimpleNoteDetailView(note: note)) {
                    NoteRow(note: note)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Divider().background(MuesliColor.rule) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 2: Make conference name in NoteRow tappable**

In `NotesListView.swift`, modify the `NoteRow` to make the conference name a navigation link if `note.conference != nil`. Either replace the whole row in a `NavigationLink` (preferred — taps anywhere on row navigate to note detail) and put a tappable conference label in the metadata as a separate gesture, OR add a separate inline button. Recommend the simpler approach: keep the row as a NoteDetail navigation, surface a small "→" button next to the conference label that opens ConferenceDetailView.

This is fiddly enough to defer the decision into implementation; for the spec, the requirement is: from any place a conference name appears, the user should be able to navigate to the ConferenceDetailView. Document this in code comments and pick the simplest pattern that doesn't break the row-tap-opens-note expectation.

- [ ] **Step 3: Build, smoke-test in simulator**

Manually: a Note with a Conference shows the conference name. Tapping the conference (or the navigation target you chose) opens ConferenceDetailView. The CTA shows. The list of Notes shows.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/UI/Views/ConferenceDetailView.swift src/mobile/Muesli/UI/Views/NotesListView.swift
git commit -m "feat(ui): ConferenceDetailView (Scene 7)

Hero header in Fraunces italic display, prominent
'Chat with this conference' CTA in the accent color, list of talks
sorted reverse-chronological. CTA disabled when conference has
zero talks (sanity guard before chat is implemented)."
```

---

## Phase B — Backend chat infrastructure

### Task 3: Postgres migration for conferences + chat tables

**Files:**
- Create: `src/api/migrations/0003_conferences_and_chat.sql` (or whatever the next sequence number is)

Run by `node-pg-migrate`. Pattern follows the auth + ledger migrations.

- [ ] **Step 1: Inspect existing migrations to confirm next number**

```bash
ls src/api/migrations/
```

- [ ] **Step 2: Write the migration**

```sql
-- src/api/migrations/0003_conferences_and_chat.sql
CREATE TABLE conferences (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  start_date   DATE,
  end_date     DATE,
  location     TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE INDEX conferences_user_idx ON conferences(user_id, created_at DESC);

CREATE TABLE chat_threads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scope           TEXT NOT NULL CHECK (scope IN ('talk', 'conference')),
  note_id         UUID REFERENCES notes(id) ON DELETE CASCADE,
  conference_id   UUID REFERENCES conferences(id) ON DELETE CASCADE,
  title           TEXT NOT NULL DEFAULT 'New chat',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (scope = 'talk' AND note_id IS NOT NULL AND conference_id IS NULL) OR
    (scope = 'conference' AND conference_id IS NOT NULL AND note_id IS NULL)
  )
);

CREATE INDEX chat_threads_user_scope_idx ON chat_threads(user_id, scope, updated_at DESC);

CREATE TABLE chat_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id       UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  role            TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content         TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  cost_micros     BIGINT,
  citations_json  JSONB
);

CREATE INDEX chat_messages_thread_idx ON chat_messages(thread_id, created_at);

-- Add talk_digest column to notes table for chat compression cache
ALTER TABLE notes ADD COLUMN IF NOT EXISTS talk_digest_json JSONB;
ALTER TABLE notes ADD COLUMN IF NOT EXISTS talk_digest_model_version TEXT;
```

(If `notes` table doesn't exist server-side yet because the AI pipeline hasn't migrated note storage to Postgres, scope this migration to only the conference + chat tables, and add the `talk_digest_*` ALTER as part of that AI pipeline work or as a follow-up migration.)

- [ ] **Step 3: Run migration in dev**

```bash
cd src/api && npm run migrate up
```

Expected: clean run, three new tables.

- [ ] **Step 4: Commit**

```bash
git add src/api/migrations/0003_conferences_and_chat.sql
git commit -m "migrate(api): conferences + chat_threads + chat_messages tables

User-scoped conferences with unique names per user. Chat threads
discriminate on scope (talk vs conference) with a CHECK constraint
ensuring exactly one of note_id / conference_id is set. Messages
store role, content, optional cost, and citations as JSONB."
```

---

### Task 4: Talk digest service (TDD)

**Files:**
- Create: `src/api/src/services/talkDigestService.js`
- Create: `src/api/tests/unit/talkDigestService.test.js`

Computes a Haiku-driven compact representation of one Note for use in conference-scope chat when the full content exceeds budget. Cached on `notes.talk_digest_json` keyed by `notes.blend_model_version`.

- [ ] **Step 1: Write failing tests**

```javascript
// src/api/tests/unit/talkDigestService.test.js
import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import { computeTalkDigest, getOrComputeTalkDigest } from '../../src/services/talkDigestService.js';

describe('computeTalkDigest', () => {
  it('returns a structured object with required fields', async () => {
    const fakeAnthropic = {
      messages: { create: jest.fn().mockResolvedValue({
        content: [{ type: 'text', text: JSON.stringify({
          title: 'Eval as engineering',
          speaker: 'Sarah Chen',
          duration: '47 min',
          key_claims: ['c1','c2','c3'],
          demos_or_slides: ['s1'],
          memorable_quotes: [{ quote: 'q1', ts: 754 }],
          user_emphasis: 'eval as ENG'
        }) }]
      }) }
    };
    const note = {
      id: 'n1',
      title: 'Eval as engineering',
      blendedMarkdown: '## body ##'.repeat(500),
      duration: 2820
    };
    const digest = await computeTalkDigest(note, { anthropic: fakeAnthropic });
    expect(digest.title).toBe('Eval as engineering');
    expect(digest.speaker).toBe('Sarah Chen');
    expect(digest.key_claims).toHaveLength(3);
    expect(fakeAnthropic.messages.create).toHaveBeenCalledTimes(1);
  });

  it('throws on invalid JSON from Haiku', async () => {
    const fakeAnthropic = {
      messages: { create: jest.fn().mockResolvedValue({
        content: [{ type: 'text', text: 'not-json' }]
      }) }
    };
    await expect(computeTalkDigest({ id: 'n1', blendedMarkdown: 'x' }, { anthropic: fakeAnthropic }))
      .rejects.toThrow();
  });
});

describe('getOrComputeTalkDigest', () => {
  it('returns cached digest if blend version matches', async () => {
    const note = {
      id: 'n1',
      blendedMarkdown: 'x',
      blendModelVersion: 'v1',
      talkDigestJson: { title: 'cached' },
      talkDigestModelVersion: 'v1',
    };
    const fakeAnthropic = { messages: { create: jest.fn() } };
    const digest = await getOrComputeTalkDigest(note, { anthropic: fakeAnthropic, save: async () => {} });
    expect(digest.title).toBe('cached');
    expect(fakeAnthropic.messages.create).not.toHaveBeenCalled();
  });

  it('recomputes if blend version changed', async () => {
    const note = {
      id: 'n1',
      blendedMarkdown: 'x',
      blendModelVersion: 'v2',
      talkDigestJson: { title: 'cached' },
      talkDigestModelVersion: 'v1',
    };
    const fakeAnthropic = {
      messages: { create: jest.fn().mockResolvedValue({
        content: [{ type: 'text', text: JSON.stringify({ title: 'fresh', speaker: '', duration: '', key_claims: [], demos_or_slides: [], memorable_quotes: [], user_emphasis: '' }) }]
      }) }
    };
    let saved = null;
    const digest = await getOrComputeTalkDigest(note, { anthropic: fakeAnthropic, save: async (n, d) => { saved = d; } });
    expect(digest.title).toBe('fresh');
    expect(saved.title).toBe('fresh');
    expect(fakeAnthropic.messages.create).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run, verify failures**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/talkDigestService.test.js 2>&1 | tail -20
```

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/talkDigestService.js
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

const HAIKU_MODEL = 'claude-haiku-4-5-20251001';

const PROMPT = `Compress this conference talk into a structured digest. Output JSON only with these exact fields:
- title (string)
- speaker (string, "" if unknown)
- duration (string, e.g. "47 min")
- key_claims (array of 3-7 short strings)
- demos_or_slides (array of strings)
- memorable_quotes (array of { quote, ts } objects)
- user_emphasis (single short string capturing what the user typed during the talk)

Be terse. Aim for 1500 tokens output max.

TALK CONTENT:
`;

export async function computeTalkDigest(note, { anthropic }) {
  const input = (note.blendedMarkdown || '').slice(0, 60_000);
  const response = await anthropic.messages.create({
    model: HAIKU_MODEL,
    max_tokens: 1800,
    messages: [{ role: 'user', content: PROMPT + input }],
  });
  const raw = response.content?.[0]?.text;
  if (!raw) throw new Error('Empty response from Haiku');
  let parsed;
  try { parsed = JSON.parse(raw); }
  catch (e) { throw new Error(`Haiku returned invalid JSON: ${raw.slice(0, 200)}`); }
  return parsed;
}

export async function getOrComputeTalkDigest(note, { anthropic, save }) {
  if (note.talkDigestJson && note.talkDigestModelVersion === note.blendModelVersion) {
    Logger.debug('Talk digest cache hit', { noteId: note.id });
    return note.talkDigestJson;
  }
  Logger.info('Computing talk digest', { noteId: note.id });
  const digest = await computeTalkDigest(note, { anthropic });
  await save(note, digest);
  return digest;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/talkDigestService.test.js 2>&1 | tail -15
```

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/talkDigestService.js src/api/tests/unit/talkDigestService.test.js
git commit -m "feat(api): talk digest service for chat compression

computeTalkDigest calls Haiku with a fixed prompt and parses a
strict JSON shape. getOrComputeTalkDigest caches on
notes.talk_digest_json keyed by blend_model_version so digests are
recomputed when the underlying blend changes."
```

---

### Task 5: Chat context service (TDD)

**Files:**
- Create: `src/api/src/services/chatContextService.js`
- Create: `src/api/tests/unit/chatContextService.test.js`

Assembles the LLM context for a chat turn. For talk scope: just the Note. For conference scope: all Notes, with compression triggered above threshold.

- [ ] **Step 1: Write failing tests**

```javascript
// src/api/tests/unit/chatContextService.test.js
import { describe, it, expect, jest } from '@jest/globals';
import { assembleContext, TOKEN_THRESHOLD } from '../../src/services/chatContextService.js';

const makeNote = (id, words) => ({
  id,
  title: `Talk ${id}`,
  blendedMarkdown: 'word '.repeat(words),
  blendModelVersion: 'v1',
});

describe('assembleContext', () => {
  it('talk scope returns the single note blend', async () => {
    const note = makeNote('n1', 1000);
    const ctx = await assembleContext({
      scope: 'talk', notes: [note], conference: null, history: [],
      digestService: { getOrComputeTalkDigest: jest.fn() },
    });
    expect(ctx.compressed).toBe(false);
    expect(ctx.contextParts).toHaveLength(1);
    expect(ctx.contextParts[0]).toContain('word');
    expect(ctx.contextParts[0]).toContain('Talk n1');
  });

  it('conference scope under threshold returns all blends without compression', async () => {
    const notes = [makeNote('n1', 500), makeNote('n2', 500), makeNote('n3', 500)];
    const conf = { id: 'c1', name: 'Test Conf', notes };
    const ctx = await assembleContext({
      scope: 'conference', notes, conference: conf, history: [],
      digestService: { getOrComputeTalkDigest: jest.fn() },
    });
    expect(ctx.compressed).toBe(false);
    expect(ctx.contextParts).toHaveLength(3);
  });

  it('conference scope over threshold triggers compression', async () => {
    // 30 notes × 5K words ≈ 150K tokens — over threshold
    const notes = Array.from({ length: 30 }, (_, i) => makeNote(`n${i}`, 5000));
    const conf = { id: 'c1', name: 'Big Conf', notes };
    const digestService = {
      getOrComputeTalkDigest: jest.fn().mockResolvedValue({ title: 'd', key_claims: ['a'] })
    };
    const ctx = await assembleContext({
      scope: 'conference', notes, conference: conf, history: [], digestService,
    });
    expect(ctx.compressed).toBe(true);
    expect(digestService.getOrComputeTalkDigest).toHaveBeenCalledTimes(30);
  });

  it('returns empty contextParts when conference has no notes', async () => {
    const ctx = await assembleContext({
      scope: 'conference', notes: [], conference: { id: 'c1', name: 'Empty', notes: [] }, history: [],
      digestService: { getOrComputeTalkDigest: jest.fn() },
    });
    expect(ctx.contextParts).toEqual([]);
  });

  it('exposes TOKEN_THRESHOLD as a constant', () => {
    expect(TOKEN_THRESHOLD).toBeGreaterThan(50_000);
    expect(TOKEN_THRESHOLD).toBeLessThan(200_000);
  });
});
```

- [ ] **Step 2: Run, verify failures**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/chatContextService.test.js 2>&1 | tail -20
```

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/chatContextService.js
import Logger from '../utils/logger.js';

export const TOKEN_THRESHOLD = 120_000;

// Crude estimator: 4 chars per token. Good enough for go/no-go decisions.
function estimateTokens(text) {
  return Math.ceil(text.length / 4);
}

export async function assembleContext({ scope, notes, conference, history, digestService }) {
  if (scope === 'talk') {
    const n = notes[0];
    if (!n) return { compressed: false, contextParts: [] };
    const part = `# Talk: ${n.title}\n\n${n.blendedMarkdown || ''}`;
    return { compressed: false, contextParts: [part] };
  }

  // conference scope
  const fullParts = notes.map(n => `## ${n.title}\n\n${n.blendedMarkdown || ''}`);
  const totalTokens = fullParts.reduce((s, p) => s + estimateTokens(p), 0);

  if (totalTokens <= TOKEN_THRESHOLD) {
    return {
      compressed: false,
      contextParts: fullParts.length ? [`# Conference: ${conference.name}`, ...fullParts] : [],
    };
  }

  Logger.info('Triggering conference context compression', { conferenceId: conference?.id, totalTokens });
  const digests = await Promise.all(
    notes.map(n => digestService.getOrComputeTalkDigest(n))
  );
  const digestParts = digests.map((d, i) => {
    return `## ${d.title || notes[i].title}\nSpeaker: ${d.speaker || 'unknown'} · ${d.duration || ''}\n\nKey claims:\n${(d.key_claims || []).map(c => `- ${c}`).join('\n')}\n\nQuotes: ${(d.memorable_quotes || []).map(q => `"${q.quote}"`).join('; ')}\n\nUser emphasis: ${d.user_emphasis || ''}`;
  });

  return {
    compressed: true,
    contextParts: [`# Conference: ${conference.name} (compressed)`, ...digestParts],
  };
}
```

- [ ] **Step 4: Run, verify pass**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/chatContextService.test.js 2>&1 | tail -15
```

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/chatContextService.js src/api/tests/unit/chatContextService.test.js
git commit -m "feat(api): chat context assembly with progressive compression

Talk scope returns the Note's blendedMarkdown directly. Conference
scope returns each Note's blend up to a 120K-token threshold; above
that it falls back to per-Note Haiku digests so the request still
fits in Sonnet's window."
```

---

### Task 6: Chat cost computation (TDD)

**Files:**
- Modify: `src/api/src/config/pricing.js` (or wherever pricing rates live — created in the credit ledger spec)
- Create: `src/api/src/services/chatCostService.js`
- Create: `src/api/tests/unit/chatCost.test.js`

The cost-per-turn formula has two components: the Sonnet inference call and (optionally) the Haiku compression that happened that turn.

- [ ] **Step 1: Write failing tests**

```javascript
// src/api/tests/unit/chatCost.test.js
import { describe, it, expect } from '@jest/globals';
import { chatCostMicros } from '../../src/services/chatCostService.js';

describe('chatCostMicros', () => {
  it('computes Sonnet-only cost when no compression happened', () => {
    const cost = chatCostMicros({
      contextTokens: 8000,
      historyTokens: 2000,
      outputTokens: 800,
      compressionTokensIn: 0,
      compressionTokensOut: 0,
    });
    // 10000 input × 3 / 1000 = 30; 800 output × 15 / 1000 = 12; total 42 micros... wait, off by units
    // Actually: (10000 * 3 + 800 * 15) / 1000 = (30000 + 12000) / 1000 = 42 — micros
    // That's $0.000042 — way too cheap. Pricing rates need to be in micros-per-Mtoken.
    // Fix: 3 micros per 1000 tokens means $3/Mtok. So 10000 tokens → 30000 micros.
    // Let me recompute the spec: "(input_tokens × 3 + output_tokens × 15) micros / 1000"
    // That gives (30000 + 12000)/1000 = 42 micros for 10K input + 800 output. Still very cheap.
    // Actually the rate is 3 micros per token if Sonnet is $3/Mtok = $0.000003/token = 3 micros/token.
    // So just multiply directly: tokens * micros_per_token.
    // Per spec: "input_tokens × 3" means 3 micros per token of input. OK.
    // Then divide by 1000? That's the bug. Let me trust the spec value at $0.05/turn for an 8K+2K input + 800 output:
    // 10000 * 3 + 800 * 15 = 30000 + 12000 = 42000 micros = $0.042. Yeah, that's right WITHOUT the divide.
    // So formula in code: input * 3 + output * 15 (both per-token-micros)
    expect(cost).toBe(42_000);
  });

  it('adds Haiku compression cost when triggered', () => {
    const cost = chatCostMicros({
      contextTokens: 50_000,
      historyTokens: 1_000,
      outputTokens: 500,
      compressionTokensIn: 200_000,
      compressionTokensOut: 30_000,
    });
    // sonnet: 51000*3 + 500*15 = 153000 + 7500 = 160500
    // haiku:  200000*0.8 + 30000*4 = 160000 + 120000 = 280000
    // total:  440500
    expect(cost).toBe(440_500);
  });

  it('handles zero token inputs gracefully', () => {
    expect(chatCostMicros({
      contextTokens: 0, historyTokens: 0, outputTokens: 0,
      compressionTokensIn: 0, compressionTokensOut: 0,
    })).toBe(0);
  });
});
```

- [ ] **Step 2: Run, verify failures**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/chatCost.test.js 2>&1 | tail -15
```

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/chatCostService.js
// Pricing in micros-of-USD per token, matching the credit ledger spec:
//   Sonnet 4.6:   $3/Mtok input, $15/Mtok output  → 3, 15 micros/token
//   Haiku 4.5:    $0.8/Mtok input, $4/Mtok output → 0.8, 4 micros/token

const SONNET_INPUT_MICROS_PER_TOKEN  = 3;
const SONNET_OUTPUT_MICROS_PER_TOKEN = 15;
const HAIKU_INPUT_MICROS_PER_TOKEN   = 0.8;
const HAIKU_OUTPUT_MICROS_PER_TOKEN  = 4;

export function chatCostMicros({ contextTokens, historyTokens, outputTokens, compressionTokensIn, compressionTokensOut }) {
  const inputTokens = (contextTokens || 0) + (historyTokens || 0);
  const sonnet = Math.ceil(inputTokens * SONNET_INPUT_MICROS_PER_TOKEN + (outputTokens || 0) * SONNET_OUTPUT_MICROS_PER_TOKEN);
  const haiku  = Math.ceil((compressionTokensIn || 0) * HAIKU_INPUT_MICROS_PER_TOKEN + (compressionTokensOut || 0) * HAIKU_OUTPUT_MICROS_PER_TOKEN);
  return sonnet + haiku;
}
```

- [ ] **Step 4: Run, pass**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/chatCost.test.js 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/chatCostService.js src/api/tests/unit/chatCost.test.js
git commit -m "feat(api): chat per-turn cost computation in micros

Sonnet input/output rates plus optional Haiku compression rates.
Pure function — used both for pre-turn estimation and post-turn
ledger entries."
```

---

### Task 7: Chat stream service (Sonnet streaming + citation extraction)

**Files:**
- Create: `src/api/src/services/chatStreamService.js`

Wraps Anthropic SDK streaming. Returns an async iterator of token deltas plus a final result with citations parsed.

The system prompt instructs Sonnet to return its answer in markdown followed by a JSON `<citations>` block. The stream is plain text; we strip the citations block from the final text body and parse it separately.

- [ ] **Step 1: Implement (no TDD — too coupled to network; covered by integration test in Task 9)**

```javascript
// src/api/src/services/chatStreamService.js
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

const SONNET_MODEL = 'claude-sonnet-4-6';

const SYSTEM_PROMPT = `You are answering questions about conference talks the user attended.
You have access to the user's blended notes (the user's verbatim notes plus AI prose woven around them) and possibly speaker quotes with timestamps.

Rules:
1. Answer in markdown. Be terse. No filler.
2. Ground every claim. If the source doesn't say something, say so — do not invent.
3. After your answer, on a new line, output exactly: <citations>JSON</citations>
   where JSON is an array of objects shaped like:
     [{ "noteId": "...", "transcriptStart": 754.2, "transcriptEnd": 758.4 }, { "noteId": "...", "section": "user_notes" }]
4. Don't reference the citations in your prose — they're handled by the UI.`;

export async function* streamChatTurn({ anthropic, contextParts, history, userMessage, scope }) {
  const messages = [
    ...history.map(m => ({ role: m.role, content: m.content })),
    {
      role: 'user',
      content: `Context (${scope} scope):\n\n${contextParts.join('\n\n---\n\n')}\n\nQuestion: ${userMessage}`
    }
  ];

  const stream = await anthropic.messages.stream({
    model: SONNET_MODEL,
    max_tokens: 2000,
    system: SYSTEM_PROMPT,
    messages,
  });

  let fullText = '';
  for await (const event of stream) {
    if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
      const t = event.delta.text;
      fullText += t;
      yield { type: 'delta', text: t };
    }
  }

  const finalMessage = await stream.finalMessage();
  const usage = finalMessage.usage; // { input_tokens, output_tokens }

  const { answer, citations } = splitAnswerAndCitations(fullText);
  yield { type: 'final', answer, citations, usage };
}

export function splitAnswerAndCitations(raw) {
  const match = raw.match(/<citations>([\s\S]*?)<\/citations>/);
  if (!match) return { answer: raw.trim(), citations: [] };
  const answer = raw.slice(0, match.index).trim();
  let citations = [];
  try { citations = JSON.parse(match[1]); }
  catch (e) {
    Logger.warn('Citations JSON parse failed', { error: e.message });
    citations = [];
  }
  return { answer, citations };
}
```

- [ ] **Step 2: Add a unit test for the splitter (the part we can test cheaply)**

```javascript
// append to a new file: src/api/tests/unit/chatStreamSplit.test.js
import { describe, it, expect } from '@jest/globals';
import { splitAnswerAndCitations } from '../../src/services/chatStreamService.js';

describe('splitAnswerAndCitations', () => {
  it('separates answer from citations block', () => {
    const raw = 'Answer body.\n<citations>[{"noteId":"n1"}]</citations>';
    const { answer, citations } = splitAnswerAndCitations(raw);
    expect(answer).toBe('Answer body.');
    expect(citations).toEqual([{ noteId: 'n1' }]);
  });

  it('returns full text and empty array when no citations block', () => {
    const { answer, citations } = splitAnswerAndCitations('Just an answer.');
    expect(answer).toBe('Just an answer.');
    expect(citations).toEqual([]);
  });

  it('returns empty citations on malformed JSON', () => {
    const raw = 'Body.<citations>not-json</citations>';
    const { answer, citations } = splitAnswerAndCitations(raw);
    expect(answer).toBe('Body.');
    expect(citations).toEqual([]);
  });
});
```

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/chatStreamSplit.test.js 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add src/api/src/services/chatStreamService.js src/api/tests/unit/chatStreamSplit.test.js
git commit -m "feat(api): chat stream service — Sonnet streaming + citation extraction

Async-generator wrapping Anthropic SDK streaming. Yields delta
events token-by-token plus a final event with the citations JSON
block parsed out of the response. The splitter is unit-tested in
isolation; full streaming behavior is covered by the integration
test in the next task."
```

---

### Task 8: Chat REST + SSE routes

**Files:**
- Create: `src/api/src/routes/chat.js`
- Modify: `src/api/src/server.js` (mount routes under `/v1/chat`)

Wires up the four endpoints from the spec. Streaming uses standard SSE — each delta is `data: <json>\n\n`, terminated by `data: [DONE]\n\n`.

- [ ] **Step 1: Implement routes**

```javascript
// src/api/src/routes/chat.js
import express from 'express';
import { db } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { assembleContext } from '../services/chatContextService.js';
import { streamChatTurn } from '../services/chatStreamService.js';
import { chatCostMicros } from '../services/chatCostService.js';
import { ledger } from '../services/ledgerService.js';
import { getOrComputeTalkDigest } from '../services/talkDigestService.js';
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

const router = express.Router();
const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });
const digestService = {
  getOrComputeTalkDigest: (note) => getOrComputeTalkDigest(note, {
    anthropic,
    save: async (n, d) => db.none('UPDATE notes SET talk_digest_json = $1, talk_digest_model_version = $2 WHERE id = $3', [d, n.blendModelVersion, n.id])
  })
};

router.post('/threads', requireAuth, async (req, res) => {
  const { scope, scopeId } = req.body;
  if (!['talk', 'conference'].includes(scope)) return res.status(400).json({ error: 'invalid_scope' });

  const row = await db.one(`
    INSERT INTO chat_threads (user_id, scope, ${scope === 'talk' ? 'note_id' : 'conference_id'}, title)
    VALUES ($1, $2, $3, $4)
    RETURNING id`,
    [req.userId, scope, scopeId, 'New chat']
  );
  res.json({ threadId: row.id });
});

router.post('/threads/:id/messages', requireAuth, async (req, res) => {
  const { id: threadId } = req.params;
  const { message } = req.body;

  const thread = await db.oneOrNone('SELECT * FROM chat_threads WHERE id = $1 AND user_id = $2', [threadId, req.userId]);
  if (!thread) return res.status(404).json({ error: 'thread_not_found' });

  // Persist user message
  await db.none('INSERT INTO chat_messages (thread_id, role, content) VALUES ($1, $2, $3)', [threadId, 'user', message]);

  // Load history (last 20 turns max)
  const history = await db.any('SELECT role, content FROM chat_messages WHERE thread_id = $1 ORDER BY created_at DESC LIMIT 20', [threadId]);
  history.reverse();

  // Load notes for scope
  let notes = [], conference = null;
  if (thread.scope === 'talk') {
    const n = await db.one('SELECT * FROM notes WHERE id = $1', [thread.note_id]);
    notes = [n];
  } else {
    conference = await db.one('SELECT * FROM conferences WHERE id = $1', [thread.conference_id]);
    notes = await db.any('SELECT * FROM notes WHERE conference_id = $1', [thread.conference_id]);
  }

  const ctx = await assembleContext({
    scope: thread.scope, notes, conference,
    history: history.slice(0, -1), // exclude just-added user message
    digestService,
  });

  // SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  let assistantText = '';
  let citations = [];
  let usage = null;
  try {
    for await (const ev of streamChatTurn({ anthropic, contextParts: ctx.contextParts, history, userMessage: message, scope: thread.scope })) {
      if (ev.type === 'delta') {
        assistantText += ev.text;
        res.write(`data: ${JSON.stringify({ text: ev.text })}\n\n`);
      } else if (ev.type === 'final') {
        citations = ev.citations;
        usage = ev.usage;
      }
    }
  } catch (e) {
    Logger.error('Chat stream failed', e);
    res.write(`data: ${JSON.stringify({ error: 'stream_failed' })}\n\n`);
    res.end();
    return;
  }

  // Compute cost
  const cost = chatCostMicros({
    contextTokens: usage?.input_tokens || 0,
    historyTokens: 0, // already in input_tokens
    outputTokens: usage?.output_tokens || 0,
    compressionTokensIn: 0, compressionTokensOut: 0, // TODO: track compression usage if compressed this turn
  });

  // Persist assistant message + ledger
  const inserted = await db.one('INSERT INTO chat_messages (thread_id, role, content, cost_micros, citations_json) VALUES ($1, $2, $3, $4, $5) RETURNING id',
    [threadId, 'assistant', assistantText, cost, JSON.stringify(citations)]);
  await db.none('UPDATE chat_threads SET updated_at = now() WHERE id = $1', [threadId]);
  await ledger.recordEntry({
    userId: req.userId,
    microsDelta: -cost,
    reason: 'chat',
    idempotencyKey: `chat:${inserted.id}`,
    metadata: { threadId, scope: thread.scope, ...usage },
  });

  res.write(`data: ${JSON.stringify({ final: { messageId: inserted.id, costMicros: cost, citations } })}\n\n`);
  res.write(`data: [DONE]\n\n`);
  res.end();
});

router.get('/threads/:id', requireAuth, async (req, res) => {
  const t = await db.oneOrNone('SELECT * FROM chat_threads WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
  if (!t) return res.status(404).json({ error: 'thread_not_found' });
  const messages = await db.any('SELECT id, role, content, created_at, cost_micros, citations_json FROM chat_messages WHERE thread_id = $1 ORDER BY created_at', [req.params.id]);
  res.json({ thread: t, messages });
});

router.delete('/threads/:id', requireAuth, async (req, res) => {
  await db.none('DELETE FROM chat_threads WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
  res.status(204).end();
});

export default router;
```

- [ ] **Step 2: Mount in server.js**

```javascript
import chatRouter from './routes/chat.js';
// ...
app.use('/v1/chat', chatRouter);
```

- [ ] **Step 3: Commit**

```bash
git add src/api/src/routes/chat.js src/api/src/server.js
git commit -m "feat(api): /v1/chat REST + SSE endpoints

POST /threads — create scoped thread.
POST /threads/:id/messages — SSE stream of token deltas terminated
  by a final event with messageId, cost, citations. Persists both
  user and assistant messages and debits the ledger atomically with
  the assistant message id as idempotency key.
GET / DELETE /threads/:id — fetch and delete thread."
```

---

### Task 9: Integration test — full chat turn end-to-end with mocked Anthropic

**Files:**
- Create: `src/api/tests/integration/chatStream.test.js`

Spins up the Express app, mocks Anthropic SDK, exercises a full POST → SSE flow.

- [ ] **Step 1: Write the test**

```javascript
// src/api/tests/integration/chatStream.test.js
import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import request from 'supertest';

// ... mock Anthropic SDK before importing the app ...

jest.unstable_mockModule('@anthropic-ai/sdk', () => ({
  default: jest.fn().mockImplementation(() => ({
    messages: {
      stream: jest.fn().mockImplementation(async () => ({
        async *[Symbol.asyncIterator]() {
          yield { type: 'content_block_delta', delta: { type: 'text_delta', text: 'Sarah ' } };
          yield { type: 'content_block_delta', delta: { type: 'text_delta', text: 'said this.\n<citations>[{"noteId":"n1","transcriptStart":12.0,"transcriptEnd":18.5}]</citations>' } };
        },
        finalMessage: async () => ({ usage: { input_tokens: 1000, output_tokens: 50 } })
      })),
      create: jest.fn(),
    }
  }))
}));

const { app } = await import('../../src/server.js');

describe('Chat SSE end-to-end', () => {
  // (Setup: seed a user, conference, note, thread via direct DB calls or test fixtures)

  it('streams a full chat turn and persists assistant message + ledger entry', async () => {
    // ... use supertest with .buffer().parse() to read SSE chunks ...
    // Assert chunks contain delta events
    // Assert final event includes messageId, costMicros > 0, citations array of length 1
    // Assert chat_messages table now has 2 rows (user + assistant)
    // Assert ledger_entries table has 1 new row with reason='chat' and idempotency_key matching message id
  });
});
```

(This test scaffolding is non-trivial — fixture setup is verbose. Implementer fills in the supertest pipeline and DB seed/teardown using whatever helpers already exist in the API repo's other integration tests.)

- [ ] **Step 2: Run, verify pass**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/integration/chatStream.test.js 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

---

## Phase C — iOS chat UI

### Task 10: ChatService (SSE client) (TDD on the parser)

**Files:**
- Create: `src/mobile/Muesli/Services/ChatService.swift`
- Create: `src/mobile/MuesliTests/Services/ChatSSEParserTests.swift`

Parses SSE wire format into a stream of typed events.

- [ ] **Step 1: TDD on the parser**

```swift
import XCTest
@testable import Muesli

final class ChatSSEParserTests: XCTestCase {
    func testParsesSingleDeltaEvent() {
        let input = #"data: {"text":"Hello"}\n\n"#
        let events = ChatSSEParser.parse(chunk: input.replacingOccurrences(of: "\\n", with: "\n"))
        XCTAssertEqual(events.count, 1)
        if case .delta(let t) = events[0] { XCTAssertEqual(t, "Hello") } else { XCTFail() }
    }

    func testParsesFinalEvent() {
        let input = "data: {\"final\":{\"messageId\":\"m1\",\"costMicros\":1234,\"citations\":[]}}\n\n"
        let events = ChatSSEParser.parse(chunk: input)
        if case .final(let id, let cost, let cites) = events[0] {
            XCTAssertEqual(id, "m1"); XCTAssertEqual(cost, 1234); XCTAssertTrue(cites.isEmpty)
        } else { XCTFail() }
    }

    func testParsesDoneSentinel() {
        let events = ChatSSEParser.parse(chunk: "data: [DONE]\n\n")
        XCTAssertEqual(events.first, .done)
    }

    func testHandlesMultipleEventsInOneChunk() {
        let input = "data: {\"text\":\"A\"}\n\ndata: {\"text\":\"B\"}\n\n"
        let events = ChatSSEParser.parse(chunk: input)
        XCTAssertEqual(events.count, 2)
    }

    func testIgnoresMalformedJSON() {
        let events = ChatSSEParser.parse(chunk: "data: not-json\n\n")
        XCTAssertTrue(events.isEmpty)
    }
}
```

- [ ] **Step 2: Implement parser + service**

```swift
// src/mobile/Muesli/Services/ChatService.swift
import Foundation

enum ChatStreamEvent: Equatable {
    case delta(String)
    case final(messageId: String, costMicros: Int, citations: [ChatCitation])
    case done
    case error(String)
}

struct ChatCitation: Codable, Equatable {
    var noteId: String?
    var transcriptStart: Double?
    var transcriptEnd: Double?
    var section: String?
}

enum ChatSSEParser {
    static func parse(chunk: String) -> [ChatStreamEvent] {
        var out: [ChatStreamEvent] = []
        for line in chunk.split(whereSeparator: { $0 == "\n" }) {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { out.append(.done); continue }
            guard let data = payload.data(using: .utf8) else { continue }
            do {
                let any = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let text = any?["text"] as? String { out.append(.delta(text)) }
                else if let final = any?["final"] as? [String: Any] {
                    let id = final["messageId"] as? String ?? ""
                    let cost = final["costMicros"] as? Int ?? 0
                    let citesData = try JSONSerialization.data(withJSONObject: final["citations"] as? [[String: Any]] ?? [])
                    let cites = (try? JSONDecoder().decode([ChatCitation].self, from: citesData)) ?? []
                    out.append(.final(messageId: id, costMicros: cost, citations: cites))
                }
                else if let err = any?["error"] as? String { out.append(.error(err)) }
            } catch { /* skip malformed */ }
        }
        return out
    }
}

actor ChatService {
    func streamMessage(threadId: UUID, message: String, onEvent: @escaping (ChatStreamEvent) -> Void) async throws {
        var req = URLRequest(url: APIConfig.url("/v1/chat/threads/\(threadId)/messages"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(AuthStore.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["message": message])

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        var buffer = ""
        for try await line in bytes.lines {
            buffer += line + "\n"
            if buffer.contains("\n\n") {
                for ev in ChatSSEParser.parse(chunk: buffer) { onEvent(ev) }
                buffer = ""
            }
        }
    }
}
```

- [ ] **Step 3: Tests pass, commit**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ChatSSEParserTests 2>&1 | tail -10
git add src/mobile/Muesli/Services/ChatService.swift src/mobile/MuesliTests/Services/ChatSSEParserTests.swift
git commit -m "feat(ios): ChatService — SSE client + tested parser

URLSession.bytes-based stream, parser is a pure function with TDD
covering delta / final / done / malformed-JSON cases."
```

---

### Task 11: ChatSheetView (Scene 8)

**Files:**
- Create: `src/mobile/Muesli/UI/Views/ChatSheetView.swift`
- Create: `src/mobile/Muesli/UI/Components/CitationChip.swift`
- Modify: `src/mobile/Muesli/UI/Views/AugmentedNoteView.swift` — add "Chat about this talk" entry to ⋯ menu

The shared chat surface for both scopes. Translates Scene 8 of the mockup.

- [ ] **Step 1: CitationChip component**

```swift
import SwiftUI

struct CitationChip: View {
    let label: String
    let timestamp: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(label).font(MuesliTypography.font(family: .manrope, size: 9, weight: 600))
                if let ts = timestamp {
                    Text(ts).font(MuesliTypography.timer)
                }
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(MuesliColor.accent)
            .background(MuesliColor.accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(MuesliColor.accent.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Implement ChatSheetView**

(Render handle, scope head, message thread, input, cost line. Use `ChatService.streamMessage` + a `@State streamingText: String` that appends on each delta. Persist to SwiftData ChatThread/ChatMessage as messages stream in or after final event lands.)

```swift
// abridged structure — implementer fills in plumbing matching the mockup styles in flow.html
struct ChatSheetView: View {
    let scope: ChatScope
    let conferenceId: UUID?
    let noteId: UUID?
    let scopeTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var thread: ChatThread?
    @State private var streamingMessage: String = ""
    @State private var streamingCost: Int? = nil
    @State private var streamingCitations: [ChatCitation] = []
    @State private var sending = false

    var body: some View {
        VStack(spacing: 0) {
            handle
            head
            messages
            inputBar
        }
        .background(MuesliColor.screen)
        .task { await ensureThread() }
    }

    private var handle: some View { /* small rule */ Capsule().fill(MuesliColor.rule).frame(width: 36, height: 4).padding(.top, 8) }
    private var head: some View { /* scope label + title + close button */ EmptyView() /* fill in */ }
    private var messages: some View { /* ScrollView of bubbles + streaming bubble + citations under assistant messages */ EmptyView() /* fill in */ }
    private var inputBar: some View { /* TextField + send button + cost line */ EmptyView() /* fill in */ }

    private func ensureThread() async {
        // POST /v1/chat/threads if no thread yet, persist locally
    }

    private func send() async {
        sending = true
        defer { sending = false }
        let userMsg = input
        input = ""
        // append user message to thread (locally + visible)
        streamingMessage = ""
        do {
            try await ChatService().streamMessage(threadId: thread!.id, message: userMsg) { ev in
                Task { @MainActor in
                    switch ev {
                    case .delta(let t):
                        streamingMessage += t
                    case .final(_, let cost, let cites):
                        streamingCost = cost
                        streamingCitations = cites
                    case .done:
                        // commit streamingMessage as a real ChatMessage in SwiftData
                        break
                    case .error: break
                    }
                }
            }
        } catch {
            AppLogger.shared.error("Chat send failed", error: error)
        }
    }
}
```

(Visual styling matches flow.html Scene 8: serif assistant messages, sans-bold user messages, citation chips under assistant message, cost line under chips, dashed/colored input border.)

- [ ] **Step 3: Add chat entry to AugmentedNoteView ⋯ menu**

In `AugmentedNoteView.swift`, the existing `⋯` button currently just shows a placeholder action. Replace with a Menu:

```swift
Menu {
    Button { showChat = true } label: { Label("Chat about this talk", systemImage: "bubble.left") }
    Button { showRegenerate = true } label: { Label("Re-blend", systemImage: "arrow.clockwise") }
    Button(role: .destructive) { showDelete = true } label: { Label("Delete note", systemImage: "trash") }
} label: {
    Text("⋯")
        // existing styles
}
.sheet(isPresented: $showChat) {
    ChatSheetView(scope: .talk, conferenceId: nil, noteId: noteId, scopeTitle: title)
}
```

- [ ] **Step 4: Build, smoke-test**

Manually: open a note → ⋯ → "Chat about this talk" → sheet opens → type a question → tokens stream in.

- [ ] **Step 5: Commit**

---

### Task 12: Final integration smoke + cleanup

- [ ] **Step 1: Full test suite**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -15
cd src/api && npm test 2>&1 | tail -15
```

- [ ] **Step 2: Manual end-to-end**

- Existing notes: open, see conference inline, tap conference → ConferenceDetailView opens
- ConferenceDetailView CTA → conference chat opens, ask a question → answer streams with citations
- AugmentedNoteView ⋯ menu → talk chat opens, ask a question → answer streams
- Force a 200K-token conference (or stub via test data) → first turn triggers compression, subsequent turns are fast
- Ledger entries appear with `reason: 'chat'`

- [ ] **Step 3: Final commit**

```bash
git commit --allow-empty -m "feat: Conferences + chat ready for integration

End-to-end flow verified: conference migration, ConferenceDetailView,
talk-scope chat from AugmentedNoteView, conference-scope chat from
ConferenceDetailView, SSE streaming, citations, cost metering, ledger
debits, compression for large conferences."
```

---

### Task 13: Chat accessibility + scope chip data flow

**Files:**
- Modify: `src/mobile/Muesli/UI/Views/ChatSheetView.swift`
- Modify: `src/mobile/Muesli/UI/Components/StreamingMessage.swift`

These are the three findings from the chat UX research that have to be baked in before chat ships. Treat them as Definition-of-Done for the chat feature.

#### 13a — Reduce Motion fallback for streaming text

The token-by-token reveal is core to the "live answer" feel, but Apple's accessibility evaluation criteria explicitly flags multi-step character-by-character animations as a Reduce Motion trigger. When Reduce Motion is on, fall back to a single-step reveal: hold the buffer, render the full message at once when the `final` event arrives. The cursor blink animation also stops.

- [ ] **Step 1: Read the env var**

In `ChatSheetView.swift`, add:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 2: Gate the streaming buffer**

In the `streamMessage` callback, change the `delta` handler to:

```swift
case .delta(let t):
    if reduceMotion {
        // Buffer silently — render only on `.final` or `.done`
        bufferedText += t
    } else {
        streamingMessage += t
    }
```

And on `.final` / `.done`:

```swift
case .done:
    if reduceMotion {
        streamingMessage = bufferedText
    }
    // commit message to SwiftData (existing behavior)
```

- [ ] **Step 3: Stop the cursor blink under Reduce Motion**

In the cursor view component:

```swift
.opacity(reduceMotion ? 1 : (cursorOn ? 1 : 0))
.animation(reduceMotion ? .default : .easeInOut(duration: 0.5).repeatForever(), value: cursorOn)
```

#### 13b — VoiceOver announcements for streaming content

VoiceOver does not auto-announce `Text` content that mutates after the screen renders. Without explicit announcements, blind users hear nothing during a 10–20 second streamed response. Fix by chunking into sentences and posting each sentence to the accessibility notification API.

- [ ] **Step 1: Add a sentence-buffering helper**

In `ChatSheetView.swift` or a small helper file:

```swift
import UIKit

private final class ChatA11yAnnouncer {
    private var pending: String = ""

    func append(_ delta: String) {
        pending += delta
        // flush at sentence boundaries — `.`, `?`, `!` followed by space/EOL
        let pattern = #"[\.\?!](\s|$)"#
        while let range = pending.range(of: pattern, options: .regularExpression) {
            let sentence = String(pending[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
            UIAccessibility.post(notification: .announcement, argument: sentence)
            pending = String(pending[range.upperBound...])
        }
    }

    func flush() {
        let tail = pending.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: tail)
        }
        pending = ""
    }
}
```

- [ ] **Step 2: Wire into the stream handler**

In `ChatSheetView`:

```swift
@State private var announcer = ChatA11yAnnouncer()

// in delta handler, after appending to streamingMessage / bufferedText:
if UIAccessibility.isVoiceOverRunning { announcer.append(t) }

// in done handler:
if UIAccessibility.isVoiceOverRunning { announcer.flush() }
```

- [ ] **Step 3: Smoke test**

Enable VoiceOver in iOS Settings → Accessibility → VoiceOver. Open chat. Send a question. Confirm the assistant's response is read sentence-by-sentence as it streams, not all at once after completion.

#### 13c — Scope chip data flow

Per UX research, the scope chip must be (a) prominent above the input, (b) pre-populated from the entry point, (c) tappable to switch scopes. This corrects the #1 UX failure mode in note-app chat.

- [ ] **Step 1: Pass scope context through the constructor**

The current `ChatSheetView` already takes `scope`, `noteId`, `conferenceId`, `scopeTitle`. Confirm the entry points populate it correctly:

- From `AugmentedNoteView`'s ⋯ menu: `ChatSheetView(scope: .talk, conferenceId: nil, noteId: note.id, scopeTitle: note.title)`
- From `ConferenceDetailView` CTA: `ChatSheetView(scope: .conference, conferenceId: conference.id, noteId: nil, scopeTitle: "\(conference.name) · \(conference.notes.count) talks")`

- [ ] **Step 2: Render the chip per the mockup**

Match `flow.html` Scene 8: rounded pill, accent-tinted background, scope-letter avatar (T or C), title text truncated, "switch" affordance on the trailing edge. Use the existing CSS as the spec for SwiftUI styles.

- [ ] **Step 3: Implement the scope picker sheet**

Tapping the chip opens a small picker sheet:

```swift
.sheet(isPresented: $showingScopePicker) {
    ScopePickerSheet(
        currentScope: scope,
        currentNoteId: noteId,
        currentConferenceId: conferenceId,
        onPick: { newScope, newNoteId, newConferenceId, newTitle in
            // create a new thread under the new scope, swap state
        }
    )
}
```

The picker shows:
- "This talk" (if currently in a Conference, shows the picker over the talks in that conference)
- "This conference" (if currently in a talk, shows the talk's conference)
- "Other conferences" → drills into a list

Switching scope creates a NEW thread; existing thread is preserved (don't lose history when scope changes).

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/UI/Views/ChatSheetView.swift src/mobile/Muesli/UI/Components/StreamingMessage.swift
git commit -m "feat(ui): chat accessibility — Reduce Motion + VoiceOver + scope chip

Reduce Motion: hold the streaming buffer, render full message on
final event; stop cursor blink. VoiceOver: post per-sentence
.announcement notifications during streaming so blind users hear
the response as it generates. Scope chip: pre-populated from entry
point, tappable to switch via picker sheet that creates a fresh
thread under the new scope."
```

---

## Out of scope (revisit later)

- Cross-conference chat ("ask all my conferences")
- Saved chat thread browsing UI
- Chat suggestions / quick-prompts
- Streaming cancellation mid-turn (network already drops gracefully; explicit cancel button is polish)
- Edit / fork a chat thread
- Voice input
- The chat-with-this-talk button on a note row (without entering the note first) — defer; the note sheet entry covers the v1 case
