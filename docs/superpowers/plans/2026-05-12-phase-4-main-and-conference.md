# Phase 4: MainView + ConferenceDetailView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development.

**Goal:** Replace the existing `SimpleMainView` flat list with `MainView`, which groups notes by `Conference` (and surfaces an "Other" section for ungrouped notes). Add `ConferenceDetailView` for the conference hero. Both screens push `AugmentedNoteView` for note detail. This is the navigation shell that finally hosts the Phase 3 renderer.

**Architecture:** Two new SwiftUI views + a shared `NoteRow` component. `MainView` reads `[Note]` and `[Conference]` from SwiftData and partitions them in a computed property. `ConferenceDetailView` takes a `Conference` and renders its notes. Both views use the existing `NotesListView`/row components where helpful, but a fresh `NoteRow` matches the design (speaker + date + slide count). The app's `WindowGroup` switches from `SimpleMainView` to `MainView`.

**Tech Stack:** SwiftUI, SwiftData `@Query`, Swift Testing.

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Scene i, vii.

**Deferred:**
- The "Chat with this conference" CTA on the conference detail screen wires up in Phase 6 (`ChatView`); for now it's a disabled button with the right label so the design lands.
- Stale-recording banner, search bar, and FAB are kept as-is from existing components.

---

## File Structure

**Creating:**
- `src/mobile/Muesli/Views/MainView.swift`
- `src/mobile/Muesli/Views/ConferenceDetailView.swift`
- `src/mobile/Muesli/Views/Components/NoteRow.swift`
- `src/mobile/MuesliTests/Views/MainViewTests.swift` (logic-only; no UI snapshot)
- `src/mobile/MuesliTests/Views/ConferenceDetailViewTests.swift`

**Modifying:**
- `src/mobile/Muesli/MuesliApp.swift` — flip `WindowGroup` root from `SimpleMainView` to `MainView`

---

## Task 1: `NoteRow` component

**Files:**
- Create: `src/mobile/Muesli/Views/Components/NoteRow.swift`

- [ ] **Step 1: Write the component**

```swift
//
//  NoteRow.swift
//  Muesli
//
//  Notes-list row: title + (speaker · relative date · slide count · photo count).
//

import SwiftUI

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            HStack(spacing: 4) {
                if let conf = note.resolvedConferenceName {
                    Text(conf).font(.caption.weight(.semibold)).foregroundColor(.accentColor)
                    dot
                }
                if let speaker = note.speaker {
                    Text(speaker).font(.caption).foregroundColor(.secondary)
                    dot
                }
                Text(relativeDate(note.timestamp)).font(.caption).foregroundColor(.secondary)
                if !note.photos.isEmpty {
                    dot
                    Text("\(note.photos.count) slides").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dot: some View {
        Text("·").font(.caption).foregroundColor(.secondary)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/mobile/Muesli/Views/Components/NoteRow.swift
git commit -m "feat(ios): NoteRow component — title + speaker + date + slide count

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `MainView` — conference-grouped notes list

**Files:**
- Create: `src/mobile/Muesli/Views/MainView.swift`
- Test: `src/mobile/MuesliTests/Views/MainViewTests.swift`

- [ ] **Step 1: Write failing tests for the grouping logic**

```swift
//
//  MainViewTests.swift
//  MuesliTests
//
//  Logic tests for MainView's conference-grouping helper. We don't render
//  the view; we exercise the static partition function.
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Main View Tests", .tags(.unit))
struct MainViewTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("partition groups notes by conference relationship and bucks ungrouped notes into Other")
    @MainActor
    func partitionGroupsByConference() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let summit = Conference(name: "DataSummit 2026")
        let solo = Note(title: "Standup")
        let talk1 = Note(title: "Three pillars", conference: summit)
        let talk2 = Note(title: "Streaming", conference: summit)
        [summit, solo, talk1, talk2].forEach { context.insert($0) }
        try context.save()

        let groups = MainView.partition(notes: [solo, talk1, talk2])

        // Conference group + ungrouped
        #expect(groups.count == 2)
        let summitGroup = groups.first { $0.conference?.id == summit.id }
        #expect(summitGroup?.notes.count == 2)
        let other = groups.first { $0.conference == nil }
        #expect(other?.notes.count == 1)
        #expect(other?.notes.first?.title == "Standup")
    }

    @Test("partition orders conference groups by most-recent note descending")
    @MainActor
    func conferenceGroupsOrderedByRecency() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let older = Conference(name: "Older 2024")
        let newer = Conference(name: "Newer 2026")
        let n1 = Note(title: "Old", timestamp: Date(timeIntervalSinceNow: -1_000_000), conference: older)
        let n2 = Note(title: "Recent", timestamp: Date(timeIntervalSinceNow: -1_000), conference: newer)
        [older, newer, n1, n2].forEach { context.insert($0) }
        try context.save()

        let groups = MainView.partition(notes: [n1, n2])
        #expect(groups.first?.conference?.id == newer.id)
    }
}
```

- [ ] **Step 2: Run, expect FAIL**

```
xcodebuild test ... -only-testing:MuesliTests/MainViewTests
```

- [ ] **Step 3: Implement `MainView`**

```swift
//
//  MainView.swift
//  Muesli
//
//  Conference-grouped notes list. Sections by Conference (most recently
//  active first), with an Other section for ungrouped notes. Each row
//  pushes AugmentedNoteView.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isArchived }, sort: \Note.timestamp, order: .reverse)
    private var notes: [Note]

    @State private var showingNewNote = false

    /// Group rendered in the list — either tied to a Conference or the Other bucket.
    struct Group: Identifiable {
        let conference: Conference?
        let notes: [Note]
        var id: String { conference?.id.uuidString ?? "other" }
    }

    static func partition(notes: [Note]) -> [Group] {
        var byConferenceId: [UUID: (Conference, [Note])] = [:]
        var ungrouped: [Note] = []
        for note in notes {
            if let conf = note.conference {
                if byConferenceId[conf.id] == nil {
                    byConferenceId[conf.id] = (conf, [])
                }
                byConferenceId[conf.id]?.1.append(note)
            } else {
                ungrouped.append(note)
            }
        }
        var groups = byConferenceId.values.map { Group(conference: $0.0, notes: $0.1) }
        // Sort conference groups by their most-recent note descending.
        groups.sort { (a, b) in
            let aDate = a.notes.map(\.timestamp).max() ?? .distantPast
            let bDate = b.notes.map(\.timestamp).max() ?? .distantPast
            return aDate > bDate
        }
        if !ungrouped.isEmpty {
            groups.append(Group(conference: nil, notes: ungrouped))
        }
        return groups
    }

    private var groups: [Group] { Self.partition(notes: notes) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Notes")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingNewNote = true
                        } label: {
                            Label("New note", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .sheet(isPresented: $showingNewNote) {
                    NewNoteView()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if notes.isEmpty {
            ContentUnavailableView(
                "No notes yet",
                systemImage: "doc.text",
                description: Text("Tap + to record your first note.")
            )
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.notes) { note in
                            NavigationLink(value: note) {
                                NoteRow(note: note)
                            }
                        }
                    } header: {
                        if let conference = group.conference {
                            NavigationLink(value: conference) {
                                HStack {
                                    Text(conference.name)
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Other")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                AugmentedNoteView(note: note)
            }
            .navigationDestination(for: Conference.self) { conference in
                ConferenceDetailView(conference: conference)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests + build**

```
xcodebuild test ... -only-testing:MuesliTests/MainViewTests
xcodebuild build ...
```

(Build will fail until Task 3 lands `ConferenceDetailView`. That's expected — commit Task 2 + Task 3 together.)

---

## Task 3: `ConferenceDetailView`

**Files:**
- Create: `src/mobile/Muesli/Views/ConferenceDetailView.swift`
- Test: `src/mobile/MuesliTests/Views/ConferenceDetailViewTests.swift`

- [ ] **Step 1: Tests for the date-range / talk-count helpers**

```swift
//
//  ConferenceDetailViewTests.swift
//  MuesliTests
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Conference Detail View Tests", .tags(.unit))
struct ConferenceDetailViewTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("dateRangeString uses explicit conference dates when present")
    @MainActor
    func dateRangeFromExplicitDates() async throws {
        let conf = Conference(
            name: "X",
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            endDate: Date(timeIntervalSince1970: 1_750_500_000)
        )
        let s = ConferenceDetailView.dateRangeString(conference: conf)
        #expect(s != nil)
        #expect(!s!.isEmpty)
    }

    @Test("dateRangeString returns nil when both dates are nil and no notes attached")
    @MainActor
    func dateRangeNilWhenAbsent() async throws {
        let conf = Conference(name: "X")
        #expect(ConferenceDetailView.dateRangeString(conference: conf) == nil)
    }
}
```

- [ ] **Step 2: Implement `ConferenceDetailView`**

```swift
//
//  ConferenceDetailView.swift
//  Muesli
//
//  Hero header for one conference: name, location, date range, description,
//  and a chronological list of talks under it. Chat CTA is a placeholder
//  until Phase 6 lands ChatView.
//

import SwiftUI

struct ConferenceDetailView: View {
    let conference: Conference

    private var notes: [Note] {
        conference.notes.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            Section {
                hero
                    .listRowInsets(EdgeInsets())
                    .padding()
            }

            Section("Talks · \(notes.count)") {
                if notes.isEmpty {
                    Text("No talks yet.").foregroundColor(.secondary)
                } else {
                    ForEach(notes) { note in
                        NavigationLink(value: note) {
                            NoteRow(note: note)
                        }
                    }
                }
            }
        }
        .navigationTitle(conference.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conference.name)
                .font(.largeTitle.weight(.bold))
            if let loc = conference.location {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let range = Self.dateRangeString(conference: conference) {
                Label(range, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let desc = conference.conferenceDescription, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .padding(.top, 4)
            }

            Button {
                // Phase 6 wires this to ChatView scoped to this conference.
            } label: {
                Label("Chat with this conference", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            .disabled(true)
        }
    }

    /// Builds a "Mar 14 – Mar 16, 2026" style string from explicit conference
    /// dates if present, falling back to min/max of attached note timestamps.
    /// Returns nil when no date information is available.
    static func dateRangeString(conference: Conference) -> String? {
        let start = conference.startDate ?? conference.notes.map(\.timestamp).min()
        let end = conference.endDate ?? conference.notes.map(\.timestamp).max()
        guard let start, let end else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        formatter.dateFormat = "MMM d"
        let s = formatter.string(from: start)
        let e: String
        if Calendar.current.component(.year, from: start) == Calendar.current.component(.year, from: end) {
            e = DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .none)
        } else {
            e = DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .none)
        }
        return "\(s) – \(e)"
    }
}
```

- [ ] **Step 3: Build + run tests**

```
xcodebuild build ...
xcodebuild test ... -only-testing:MuesliTests/ConferenceDetailViewTests
```

- [ ] **Step 4: Commit Tasks 2 + 3 together**

```bash
git add src/mobile/Muesli/Views/MainView.swift \
        src/mobile/Muesli/Views/ConferenceDetailView.swift \
        src/mobile/MuesliTests/Views/MainViewTests.swift \
        src/mobile/MuesliTests/Views/ConferenceDetailViewTests.swift

git commit -m "feat(ios): MainView + ConferenceDetailView

MainView groups notes by Conference (most recently active first)
with an Other bucket for ungrouped notes. Each row pushes
AugmentedNoteView via NavigationStack value-based destinations.
Tapping a conference section header pushes ConferenceDetailView.

ConferenceDetailView shows the conference name, location, date
range, and description as a hero, then lists the conference's
talks in chronological order. dateRangeString falls back to
min/max of attached note timestamps when explicit conference dates
are missing. The Chat with this conference button is a disabled
placeholder until Phase 6.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Switch app root to `MainView`

**Files:**
- Modify: `src/mobile/Muesli/MuesliApp.swift`

- [ ] **Step 1: Replace WindowGroup body**

In `MuesliApp.swift`:

```swift
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
```

- [ ] **Step 2: Build + smoke run**

```
xcodebuild build ...
```

(Then open the simulator manually if convenient and confirm the new MainView appears.)

- [ ] **Step 3: Commit**

```bash
git add src/mobile/Muesli/MuesliApp.swift
git commit -m "feat(ios): flip app root from SimpleMainView to MainView

SimpleMainView is now orphaned; Phase 9 deletes it after the
salvage harvest completes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 done when

- Four tasks committed.
- `MainViewTests` and `ConferenceDetailViewTests` green.
- Build green; lint clean.
- Simulator smoke: launch shows conference sections grouping the sample data, tapping a row pushes the augmented note, tapping a conference header pushes the conference detail with the "Chat with this conference" disabled button visible.

## Next plan

Phase 5: `ChapteredPlaybackView` — wires the tap-to-seek attributes baked into Phase 3.
