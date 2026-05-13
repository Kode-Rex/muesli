# Phase 1: Schema + Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Conference`, `ChatThread`, `ChatMessage` SwiftData models, attach `Note.conference` relationship, add `Note.speaker`, and run a one-time idempotent migration that groups existing notes by `conferenceName` into `Conference` records.

**Architecture:** Pure additive SwiftData changes (new entities + new optional fields). No `VersionedSchema` — SwiftData's default lightweight migration handles additive changes. Migration follows the existing `PhotoMigration` pattern: a static `run(in:)` function gated by a `UserDefaults` flag, invoked from `MuesliApp.init`.

**Tech Stack:** Swift 5.9+, SwiftData, Swift Testing framework (`import Testing`), with XCTest for the migration test (matching `PhotoMigrationTests` precedent).

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Data model, Schema versioning + migration.

**Deviation note vs. spec:** Spec proposed `VersionedSchema` chain `SchemaV1 → SchemaV2`. After looking at the existing setup (`MuesliApp.swift:14-17` uses a flat `Schema([Note.self, Photo.self])`), I'm skipping `VersionedSchema` because every change in this phase is purely additive — new entities and new optional fields. SwiftData handles additive changes via lightweight migration without explicit version chains. We can introduce `VersionedSchema` later if a destructive change ever needs it.

---

## File Structure

**Creating:**
- `src/mobile/Muesli/Models/Conference.swift` — new entity
- `src/mobile/Muesli/Models/ChatThread.swift` — new entity
- `src/mobile/Muesli/Models/ChatMessage.swift` — new entity
- `src/mobile/Muesli/Migration/ConferenceMigration.swift` — one-time backfill
- `src/mobile/MuesliTests/Models/ConferenceModelTests.swift` — model unit tests
- `src/mobile/MuesliTests/Models/ChatThreadModelTests.swift` — model unit tests
- `src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift` — migration tests

**Modifying:**
- `src/mobile/Muesli/Models.swift` — add `speaker: String?`, add `conference: Conference?` relationship to `Note`
- `src/mobile/Muesli/MuesliApp.swift` — register new entities in schema; invoke migration on launch
- `src/mobile/Muesli/SampleData/SampleDataManager.swift` — seed two conferences with multi-talk groupings

---

## Task 1: Create `Conference` model

**Files:**
- Create: `src/mobile/Muesli/Models/Conference.swift`
- Test: `src/mobile/MuesliTests/Models/ConferenceModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `src/mobile/MuesliTests/Models/ConferenceModelTests.swift`:

```swift
//
//  ConferenceModelTests.swift
//  MuesliTests
//
//  Unit tests for the Conference SwiftData entity.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("Conference Model Tests", .tags(.unit))
struct ConferenceModelTests {

    @Test("Conference initialization with required fields")
    func conferenceInitialization() async throws {
        let conf = Conference(name: "DataSummit 2026")

        #expect(conf.name == "DataSummit 2026")
        #expect(conf.location == nil)
        #expect(conf.startDate == nil)
        #expect(conf.endDate == nil)
        #expect(conf.conferenceDescription == nil)
        #expect(conf.notes.isEmpty)
        #expect(conf.createdAt.timeIntervalSinceNow < 1)
    }

    @Test("Conference initialization with all metadata")
    func conferenceFullInit() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_200_000)
        let conf = Conference(
            name: "DataSummit 2026",
            location: "San Francisco",
            startDate: start,
            endDate: end,
            conferenceDescription: "Annual data conference"
        )

        #expect(conf.location == "San Francisco")
        #expect(conf.startDate == start)
        #expect(conf.endDate == end)
        #expect(conf.conferenceDescription == "Annual data conference")
    }

    @Test("Conference has stable UUID")
    func conferenceStableID() async throws {
        let id = UUID()
        let conf = Conference(id: id, name: "X")
        #expect(conf.id == id)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh unit`
Expected: FAIL with "Cannot find 'Conference' in scope" (and similar) — the type doesn't exist yet.

- [ ] **Step 3: Create the Conference model**

Create `src/mobile/Muesli/Models/Conference.swift`:

```swift
//
//  Conference.swift
//  Muesli
//
//  SwiftData entity representing a conference, grouping multiple Note talks.
//

import Foundation
import SwiftData

@Model
final class Conference {
    var id: UUID
    var name: String
    var location: String?
    var startDate: Date?
    var endDate: Date?
    var conferenceDescription: String?    // `description` is reserved on NSObject
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Note.conference)
    var notes: [Note] = []

    init(
        id: UUID = UUID(),
        name: String,
        location: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        conferenceDescription: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.conferenceDescription = conferenceDescription
        self.createdAt = createdAt
    }
}
```

Note: This will not compile yet because `Note.conference` is referenced by `inverse:` but does not exist. Task 2 adds it. The plan completes the compilation cycle there.

- [ ] **Step 4: Skip running tests until Task 2 (the inverse reference needs `Note.conference` first)**

Move directly to Task 2. Do not commit yet.

---

## Task 2: Add `Note.conference` relationship and `Note.speaker`

**Files:**
- Modify: `src/mobile/Muesli/Models.swift`
- Test: `src/mobile/MuesliTests/Models/NoteModelTests.swift` (extend existing)

- [ ] **Step 1: Write the failing tests**

Append to `src/mobile/MuesliTests/Models/NoteModelTests.swift` (inside the existing `NoteModelTests` struct):

```swift
    @Test("Note speaker defaults to nil")
    func noteSpeakerDefault() async throws {
        let note = Note(title: "Talk")
        #expect(note.speaker == nil)
    }

    @Test("Note speaker can be set")
    func noteSpeakerSet() async throws {
        let note = Note(title: "Talk", speaker: "Sarah Chen")
        #expect(note.speaker == "Sarah Chen")
    }

    @Test("Note conference relationship is nil by default")
    func noteConferenceDefault() async throws {
        let note = Note(title: "Talk")
        #expect(note.conference == nil)
    }

    @Test("Note can be attached to Conference")
    func noteConferenceRelationship() async throws {
        let schema = Schema([Note.self, Photo.self, Conference.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let conf = Conference(name: "DataSummit 2026")
        let note = Note(title: "Talk")
        note.conference = conf
        context.insert(conf)
        context.insert(note)
        try context.save()

        #expect(note.conference?.name == "DataSummit 2026")
        #expect(conf.notes.count == 1)
        #expect(conf.notes.first?.title == "Talk")
    }
```

- [ ] **Step 2: Run tests to verify they fail to compile**

Run: `./scripts/test.sh unit`
Expected: FAIL — `Note` has no `speaker` or `conference` member.

- [ ] **Step 3: Modify `Note` model**

Edit `src/mobile/Muesli/Models.swift`. Replace the existing `@Relationship` block and the trailing initializer body to add the new fields. The full updated section between line 17 and the end of `init(...)` should read:

```swift
    var conferenceName: String?
    var sessionType: String // "meeting", "session", "note"
    var isArchived: Bool
    var audioFilePath: String? // Local path to audio file
    var transcriptionStatus: String // "none", "pending", "processing", "completed", "failed"
    var duration: TimeInterval? // Recording duration in seconds

    // SwiftData doesn't handle Optional arrays well, use empty array as default
    var imagePaths: [String] = [] // Array of local file paths to captured images

    var aiSummary: String? // AI-generated summary of the transcript
    var userNotes: String = "" // User's personal notes added during or after recording

    // Speaker shown in the augmented note view; user-provided or transcriber-derived.
    var speaker: String?

    // Blend pipeline outputs (populated post-stop)
    var transcript: String?
    var transcriptWordsJSON: Data?
    var blendedMarkdown: String?
    var blendCitationsJSON: Data?
    var chaptersJSON: Data?
    var blendStatusRaw: String = "idle"
    var blendError: String?
    var blendCostMicros: Int?
    var blendModelVersion: String?

    @Relationship(deleteRule: .cascade, inverse: \Photo.note) var photos: [Photo] = []

    // Conference grouping. Replaces conferenceName at the read site;
    // conferenceName is retained for one release as a fallback.
    var conference: Conference?

    var blendStatus: BlendStatus {
        get { BlendStatus(rawValue: blendStatusRaw) ?? .idle }
        set { blendStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        timestamp: Date = Date(),
        conferenceName: String? = nil,
        sessionType: String = "note",
        isArchived: Bool = false,
        audioFilePath: String? = nil,
        transcriptionStatus: String = "none",
        duration: TimeInterval? = nil,
        imagePaths: [String] = [],
        aiSummary: String? = nil,
        userNotes: String = "",
        speaker: String? = nil,
        conference: Conference? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.conferenceName = conferenceName
        self.sessionType = sessionType
        self.isArchived = isArchived
        self.audioFilePath = audioFilePath
        self.transcriptionStatus = transcriptionStatus
        self.duration = duration
        self.imagePaths = imagePaths
        self.aiSummary = aiSummary
        self.userNotes = userNotes
        self.speaker = speaker
        self.conference = conference
    }
```

Leave everything below (computed properties) unchanged.

- [ ] **Step 4: Update `MuesliApp.swift` schema list**

Edit `src/mobile/Muesli/MuesliApp.swift`. Replace the schema definition at lines 14-17:

```swift
        let schema = Schema([
            Note.self,
            Photo.self,
            Conference.self,
        ])
```

(Just adding `Conference.self`. `ChatThread` and `ChatMessage` get added in Task 3.)

- [ ] **Step 5: Run tests**

Run: `./scripts/test.sh unit`
Expected: PASS — all `ConferenceModelTests` and the four new `NoteModelTests` cases pass.

- [ ] **Step 6: Commit**

```bash
git add src/mobile/Muesli/Models/Conference.swift src/mobile/Muesli/Models.swift src/mobile/Muesli/MuesliApp.swift src/mobile/MuesliTests/Models/ConferenceModelTests.swift src/mobile/MuesliTests/Models/NoteModelTests.swift
git commit -m "feat(ios): add Conference entity and Note.conference relationship

Adds a Conference SwiftData entity with name, location, date range,
and description metadata. Note gains a conference relationship and
a speaker field. conferenceName is retained for one release as a
fallback for the migration.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Create `ChatThread` and `ChatMessage` models

**Files:**
- Create: `src/mobile/Muesli/Models/ChatThread.swift`
- Create: `src/mobile/Muesli/Models/ChatMessage.swift`
- Test: `src/mobile/MuesliTests/Models/ChatThreadModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `src/mobile/MuesliTests/Models/ChatThreadModelTests.swift`:

```swift
//
//  ChatThreadModelTests.swift
//  MuesliTests
//
//  Unit tests for the ChatThread and ChatMessage SwiftData entities.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("Chat Thread Model Tests", .tags(.unit))
struct ChatThreadModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("ChatThread initializes with talk scope")
    func chatThreadTalkScope() async throws {
        let noteId = UUID()
        let thread = ChatThread(scopeKind: .talk, scopeId: noteId)

        #expect(thread.scopeKind == .talk)
        #expect(thread.scopeId == noteId)
        #expect(thread.messages.isEmpty)
        #expect(thread.createdAt.timeIntervalSinceNow < 1)
        #expect(thread.updatedAt.timeIntervalSinceNow < 1)
    }

    @Test("ChatThread initializes with conference scope")
    func chatThreadConferenceScope() async throws {
        let confId = UUID()
        let thread = ChatThread(scopeKind: .conference, scopeId: confId)

        #expect(thread.scopeKind == .conference)
        #expect(thread.scopeId == confId)
    }

    @Test("ChatMessage initializes with role and content")
    func chatMessageInit() async throws {
        let msg = ChatMessage(role: .user, content: "Hello")

        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.citationsJSON == nil)
        #expect(msg.thread == nil)
    }

    @Test("ChatThread cascade-deletes messages")
    func chatThreadCascadeDeletes() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        let msg1 = ChatMessage(role: .user, content: "Q")
        let msg2 = ChatMessage(role: .assistant, content: "A")
        thread.messages = [msg1, msg2]
        msg1.thread = thread
        msg2.thread = thread

        context.insert(thread)
        context.insert(msg1)
        context.insert(msg2)
        try context.save()

        context.delete(thread)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ChatMessage>())
        #expect(remaining.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh unit`
Expected: FAIL with "Cannot find 'ChatThread' in scope" etc.

- [ ] **Step 3: Create `ChatThread.swift`**

Create `src/mobile/Muesli/Models/ChatThread.swift`:

```swift
//
//  ChatThread.swift
//  Muesli
//
//  SwiftData entity for a chat conversation, scoped to either a talk or a conference.
//

import Foundation
import SwiftData

enum ChatScopeKind: String, Codable {
    case talk, conference
}

@Model
final class ChatThread {
    var id: UUID
    var scopeKindRaw: String
    var scopeId: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    var messages: [ChatMessage] = []

    var scopeKind: ChatScopeKind {
        get { ChatScopeKind(rawValue: scopeKindRaw) ?? .talk }
        set { scopeKindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scopeKind: ChatScopeKind,
        scopeId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scopeKindRaw = scopeKind.rawValue
        self.scopeId = scopeId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 4: Create `ChatMessage.swift`**

Create `src/mobile/Muesli/Models/ChatMessage.swift`:

```swift
//
//  ChatMessage.swift
//  Muesli
//
//  SwiftData entity for a single chat message within a ChatThread.
//

import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user, assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var roleRaw: String
    var content: String
    var citationsJSON: Data?
    var createdAt: Date
    var thread: ChatThread?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        citationsJSON: Data? = nil,
        createdAt: Date = Date(),
        thread: ChatThread? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.citationsJSON = citationsJSON
        self.createdAt = createdAt
        self.thread = thread
    }
}
```

- [ ] **Step 5: Register new entities in `MuesliApp.swift`**

Edit `src/mobile/Muesli/MuesliApp.swift`. Update the schema definition:

```swift
        let schema = Schema([
            Note.self,
            Photo.self,
            Conference.self,
            ChatThread.self,
            ChatMessage.self,
        ])
```

- [ ] **Step 6: Run tests**

Run: `./scripts/test.sh unit`
Expected: PASS — all four `ChatThreadModelTests` cases green.

- [ ] **Step 7: Commit**

```bash
git add src/mobile/Muesli/Models/ChatThread.swift src/mobile/Muesli/Models/ChatMessage.swift src/mobile/Muesli/MuesliApp.swift src/mobile/MuesliTests/Models/ChatThreadModelTests.swift
git commit -m "feat(ios): add ChatThread and ChatMessage SwiftData entities

Adds client-side persistence for chat threads scoped to either a talk
(Note) or a conference. Messages cascade-delete with their thread.
Backend remains stateless; iOS retains conversation history.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Implement `ConferenceMigration`

**Files:**
- Create: `src/mobile/Muesli/Migration/ConferenceMigration.swift`
- Test: `src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift` (uses XCTest to mirror `PhotoMigrationTests`):

```swift
//
//  ConferenceMigrationTests.swift
//  MuesliTests
//
//  Tests the one-time backfill from Note.conferenceName strings into
//  Conference records with attached note relationships.
//

import XCTest
import SwiftData
@testable import Muesli

@MainActor
final class ConferenceMigrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ConferenceMigration.runFlagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ConferenceMigration.runFlagKey)
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testGroupsNotesByConferenceName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let n1 = Note(title: "Talk A", timestamp: Date(timeIntervalSince1970: 1_000), conferenceName: "DataSummit 2026")
        let n2 = Note(title: "Talk B", timestamp: Date(timeIntervalSince1970: 2_000), conferenceName: "DataSummit 2026")
        let n3 = Note(title: "Solo",   timestamp: Date(timeIntervalSince1970: 3_000), conferenceName: "DevWorld")
        let n4 = Note(title: "Loose",  timestamp: Date(timeIntervalSince1970: 4_000), conferenceName: nil)
        [n1, n2, n3, n4].forEach { context.insert($0) }
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 2)

        let summit = confs.first { $0.name == "DataSummit 2026" }
        XCTAssertNotNil(summit)
        XCTAssertEqual(summit?.notes.count, 2)
        XCTAssertEqual(summit?.startDate, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(summit?.endDate, Date(timeIntervalSince1970: 2_000))

        let dev = confs.first { $0.name == "DevWorld" }
        XCTAssertEqual(dev?.notes.count, 1)

        // Notes with nil conferenceName remain unattached.
        XCTAssertNil(n4.conference)
    }

    func testIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let n1 = Note(title: "A", timestamp: Date(timeIntervalSince1970: 1_000), conferenceName: "DataSummit 2026")
        context.insert(n1)
        try context.save()

        ConferenceMigration.run(in: context)
        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Running migration twice must not create duplicates")
        XCTAssertEqual(confs.first?.notes.count, 1)
    }

    func testCaseInsensitiveAndTrimmedGrouping() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let a = Note(title: "A", conferenceName: "DataSummit 2026")
        let b = Note(title: "B", conferenceName: "datasummit 2026")
        let c = Note(title: "C", conferenceName: "  DataSummit 2026  ")
        [a, b, c].forEach { context.insert($0) }
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Names differing only by case or whitespace must group")
        XCTAssertEqual(confs.first?.notes.count, 3)
    }

    func testSkipsNotesAlreadyAttached() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Conference(name: "DataSummit 2026")
        let n = Note(title: "Pre-attached", conferenceName: "DataSummit 2026")
        n.conference = existing
        context.insert(existing)
        context.insert(n)
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Existing Conference must be reused, not duplicated")
        XCTAssertEqual(confs.first?.notes.count, 1)
    }

    func testHasRunFlagSet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        XCTAssertFalse(ConferenceMigration.hasRun)
        ConferenceMigration.run(in: context)
        XCTAssertTrue(ConferenceMigration.hasRun)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh unit`
Expected: FAIL with "Cannot find 'ConferenceMigration' in scope".

- [ ] **Step 3: Implement `ConferenceMigration`**

Create `src/mobile/Muesli/Migration/ConferenceMigration.swift`:

```swift
//
//  ConferenceMigration.swift
//  Muesli
//
//  One-time migration that backfills Conference records by grouping
//  existing Notes on their legacy `conferenceName` string. Idempotent:
//  guarded by a UserDefaults flag, and reuses any pre-existing Conference
//  with a matching normalized name.
//

import Foundation
import SwiftData

enum ConferenceMigration {
    static let runFlagKey = "muesli.conferenceMigration.v1.complete"

    /// Groups notes by `conferenceName` (case-insensitive, whitespace-trimmed)
    /// and attaches them to a find-or-created `Conference`. Backfills the
    /// conference's startDate/endDate from the min/max note timestamps.
    /// Idempotent: safe to call multiple times.
    static func run(in context: ModelContext) {
        // Skip notes that already have a conference relationship.
        let unattached = (try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.conference == nil && $0.conferenceName != nil })
        )) ?? []

        // Group notes by normalized name.
        var groups: [String: (display: String, notes: [Note])] = [:]
        for note in unattached {
            guard let raw = note.conferenceName else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if groups[key] == nil {
                groups[key] = (display: trimmed, notes: [])
            }
            groups[key]?.notes.append(note)
        }

        // Find-or-create a Conference per group.
        let existing = (try? context.fetch(FetchDescriptor<Conference>())) ?? []
        var byKey: [String: Conference] = [:]
        for conf in existing {
            let key = conf.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            byKey[key] = conf
        }

        for (key, group) in groups {
            let conf: Conference
            if let found = byKey[key] {
                conf = found
            } else {
                conf = Conference(name: group.display)
                context.insert(conf)
                byKey[key] = conf
            }

            // Attach notes and refresh date range. group.notes is filtered to
            // `conference == nil`, so there's no overlap with conf.notes.
            for note in group.notes {
                note.conference = conf
            }
            let timestamps = (conf.notes + group.notes).map(\.timestamp)
            conf.startDate = timestamps.min() ?? conf.startDate
            conf.endDate = timestamps.max() ?? conf.endDate
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: runFlagKey)
    }

    static var hasRun: Bool {
        UserDefaults.standard.bool(forKey: runFlagKey)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `./scripts/test.sh unit`
Expected: PASS — all five `ConferenceMigrationTests` cases green.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/Muesli/Migration/ConferenceMigration.swift src/mobile/MuesliTests/Models/ConferenceMigrationTests.swift
git commit -m "feat(ios): add ConferenceMigration to backfill Conference records

One-time idempotent migration that groups existing notes by their
conferenceName string (case-insensitive, whitespace-trimmed) and
attaches them to a find-or-created Conference. Backfills conference
startDate/endDate from note timestamps. Guarded by a UserDefaults
flag so it does not re-run.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Wire migration into app launch

**Files:**
- Modify: `src/mobile/Muesli/MuesliApp.swift`

- [ ] **Step 1: Add migration trigger to `MuesliApp.init`**

Edit `src/mobile/Muesli/MuesliApp.swift`. After the existing `PhotoMigration` block, add:

```swift
        if !ConferenceMigration.hasRun {
            let context = ModelContext(sharedModelContainer)
            ConferenceMigration.run(in: context)
        }
```

The full `init()` after this change reads:

```swift
    init() {
        TranscriptionOrchestrator.shared.setContainer(sharedModelContainer)
        BlendOrchestrator.shared.setContainer(sharedModelContainer)

        if !PhotoMigration.hasRun {
            let context = ModelContext(sharedModelContainer)
            PhotoMigration.run(in: context, fileBytesProvider: { path in
                guard let url = AudioRecordingManager.shared.getRecordingURL(fileName: path) else { return nil }
                return try? Data(contentsOf: url)
            })
        }

        if !ConferenceMigration.hasRun {
            let context = ModelContext(sharedModelContainer)
            ConferenceMigration.run(in: context)
        }
    }
```

- [ ] **Step 2: Build the app to verify it still launches**

Run: `./scripts/build.sh`
Expected: Build succeeds. No runtime test for this step; the launch wiring is exercised in Task 7's smoke check.

- [ ] **Step 3: Commit**

```bash
git add src/mobile/Muesli/MuesliApp.swift
git commit -m "feat(ios): run ConferenceMigration on app launch

Mirrors the PhotoMigration trigger pattern. Migration is gated by a
UserDefaults flag so it runs at most once per install.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Seed conferences in `SampleDataManager`

**Files:**
- Modify: `src/mobile/Muesli/SampleData/SampleDataManager.swift`

`SampleDataManager` currently exposes `seedDatabase(context:)` which calls `generateSampleNotes() -> [Note]` and inserts the result. We will refactor so the conferences are created first inside `seedDatabase`, then passed to `generateSampleNotes(dataSummit:devWorld:)` which attaches each note to a conference (or none). `clearAllData` also needs to delete `Conference`, `ChatThread`, and `ChatMessage` so the new schema is fully reset.

- [ ] **Step 1: Replace `seedDatabase` and `generateSampleNotes`**

Edit `src/mobile/Muesli/SampleData/SampleDataManager.swift`. Replace the entire body of `seedDatabase(context:)` (lines 16-29) and the entire `generateSampleNotes()` function (lines 31-111) with:

```swift
    static func seedDatabase(context: ModelContext) {
        let conferences = generateSampleConferences()
        conferences.forEach(context.insert)

        let dataSummit = conferences[0]
        let devWorld = conferences[1]
        let sampleNotes = generateSampleNotes(dataSummit: dataSummit, devWorld: devWorld)

        for note in sampleNotes {
            context.insert(note)
        }

        do {
            try context.save()
            AppLogger.shared.dataSuccess(
                "Sample Data",
                details: "Seeded \(conferences.count) conferences and \(sampleNotes.count) notes"
            )
        } catch {
            AppLogger.shared.dataError("Sample Data", error: error)
        }
    }

    static func generateSampleConferences() -> [Conference] {
        let cal = Calendar.current
        let dataSummit = Conference(
            name: "DataSummit 2026",
            location: "San Francisco, CA",
            startDate: cal.date(from: DateComponents(year: 2026, month: 5, day: 10)),
            endDate: cal.date(from: DateComponents(year: 2026, month: 5, day: 12)),
            conferenceDescription: "Annual data and ML conference"
        )
        let devWorld = Conference(
            name: "DevWorld 2026",
            location: "Austin, TX",
            startDate: cal.date(from: DateComponents(year: 2026, month: 3, day: 14)),
            endDate: cal.date(from: DateComponents(year: 2026, month: 3, day: 16)),
            conferenceDescription: "Developer conference covering web, mobile, and platforms"
        )
        return [dataSummit, devWorld]
    }

    static func generateSampleNotes(dataSummit: Conference, devWorld: Conference) -> [Note] {
        let baseTime = Date()

        return [
            // DataSummit 2026 talks (3)
            Note(
                title: "The three pillars of data infra",
                content: "Storage, compute, and discoverability. Sarah walked through how DataSummit's flagship team rebuilt their lake-house on these primitives.",
                timestamp: baseTime.addingTimeInterval(-3600),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_three_pillars.m4a",
                transcriptionStatus: "completed",
                duration: 2400,
                speaker: "Sarah Chen",
                conference: dataSummit
            ),
            Note(
                title: "Streaming at planet scale",
                content: "Devon's deep dive on multi-region streaming, exactly-once semantics, and the operational realities they hit at year three.",
                timestamp: baseTime.addingTimeInterval(-7200),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_streaming.m4a",
                transcriptionStatus: "completed",
                duration: 2700,
                speaker: "Devon Park",
                conference: dataSummit
            ),
            Note(
                title: "Embeddings for everything",
                content: "Hina's plenary on using embeddings as the universal interface across retrieval, ranking, and dedup.",
                timestamp: baseTime.addingTimeInterval(-90000),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_embeddings.m4a",
                transcriptionStatus: "completed",
                duration: 3000,
                speaker: "Hina Yoshida",
                conference: dataSummit
            ),

            // DevWorld 2026 talks (2)
            Note(
                title: "SwiftUI performance audit",
                content: "A pragmatic tour of Instruments for SwiftUI, view identity, and the diff cost of large lists.",
                timestamp: baseTime.addingTimeInterval(-5_184_000),
                conferenceName: "DevWorld 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_swiftui_perf.m4a",
                transcriptionStatus: "completed",
                duration: 1800,
                speaker: "Aiden Reyes",
                conference: devWorld
            ),
            Note(
                title: "Edge runtimes in practice",
                content: "What works, what doesn't, and the boring middle of running production services at the edge.",
                timestamp: baseTime.addingTimeInterval(-5_270_400),
                conferenceName: "DevWorld 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0,
                speaker: "Priya Iyer",
                conference: devWorld
            ),

            // Ungrouped notes (preserved for non-conference flows)
            Note(
                title: "Team Standup",
                content: "Discussed current sprint progress. John is working on the API integration, Sarah is finishing the UI components.",
                timestamp: baseTime.addingTimeInterval(-1800),
                conferenceName: nil,
                sessionType: "meeting",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            ),
            Note(
                title: "Old Project Notes",
                content: "Legacy project documentation that's no longer active but kept for reference.",
                timestamp: baseTime.addingTimeInterval(-604800),
                conferenceName: nil,
                sessionType: "documentation",
                isArchived: true,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            )
        ]
    }
```

- [ ] **Step 2: Update `clearAllData` to clear all new entities**

In the same file, replace the `clearAllData(context:)` body (lines 115-123) with:

```swift
    static func clearAllData(context: ModelContext) {
        do {
            try context.delete(model: ChatMessage.self)
            try context.delete(model: ChatThread.self)
            try context.delete(model: Note.self)
            try context.delete(model: Conference.self)
            try context.save()
            AppLogger.shared.dataSuccess("Sample Data", details: "Cleared all data")
        } catch {
            AppLogger.shared.dataError("Sample Data Clear", error: error)
        }
    }
```

Order matters: delete child rows (`ChatMessage`, then `ChatThread`, then `Note`) before parents (`Conference`). `Photo` deletion happens implicitly via `Note.photos` cascade.

- [ ] **Step 3: Run unit tests**

Run: `./scripts/test.sh unit`
Expected: PASS. Existing sample-data validation tests continue to pass; the new conference-attached notes serialize and load correctly.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/SampleData/SampleDataManager.swift
git commit -m "feat(ios): seed two conferences in sample data

Refactors seedDatabase to build DataSummit 2026 (3 talks) and
DevWorld 2026 (2 talks) with location, date range, and descriptions.
Each conference talk includes a speaker. Two ungrouped notes are
retained for non-conference flows. clearAllData now deletes the new
ChatMessage/ChatThread/Conference entities in dependency order.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Smoke test the full launch path

**Files:** none (manual verification)

- [ ] **Step 1: Build the app**

Run: `./scripts/build.sh clean`
Expected: Clean build succeeds.

- [ ] **Step 2: Launch on simulator**

Run: `./scripts/test.sh all`
Expected: All unit and UI tests pass. SwiftData lightweight migration applies the new entities; existing notes survive; `ConferenceMigration` runs once and groups any preexisting `conferenceName` strings.

- [ ] **Step 3: Inspect via the debug menu (optional manual check)**

If `DebugMenuView` exposes a database inspector, launch the app on a simulator and confirm:
- At least one `Conference` record exists if any seed/legacy note had a `conferenceName`.
- `UserDefaults` shows `muesli.conferenceMigration.v1.complete` set to true.

This step is informational only; failures here mean Task 4 logic is wrong and the migration tests missed a case — add a regression test and fix.

- [ ] **Step 4: Run lint**

Run: `./scripts/lint.sh fix`
Expected: No SwiftLint violations introduced. Auto-fix anything that surfaces, re-run, confirm clean.

- [ ] **Step 5: Final commit if lint touched anything**

```bash
git add -A
git diff --staged --quiet || git commit -m "chore(ios): lint fixes from phase 1

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

If lint produced no changes, skip the commit.

---

## Phase 1 done when

- All seven tasks committed.
- `./scripts/test.sh unit` green.
- `./scripts/build.sh` produces a clean build.
- `./scripts/lint.sh` reports no violations.
- `Conference`, `ChatThread`, `ChatMessage` registered in the model schema.
- `Note.conference` and `Note.speaker` available.
- `ConferenceMigration` runs at launch and is idempotent.

## Next plan

Phase 2 covers the chat backend (`chatService.js`, `POST /sessions/:id/chat`, `POST /conferences/:id/chat`, tests). Written after Phase 1 merges into the feature branch.
