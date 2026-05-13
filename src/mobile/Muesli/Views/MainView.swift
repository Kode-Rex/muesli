//
//  MainView.swift
//  Muesli
//
//  Conference-grouped notes list. Sections by Conference (most recently
//  active first), with an Other section for ungrouped notes. Each row
//  pushes AugmentedNoteView via the navigation stack.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isArchived }, sort: \Note.timestamp, order: .reverse)
    private var notes: [Note]

    // All conferences — including those whose notes are all archived — so a
    // conference is still reachable on the home screen after archiving its talks.
    @Query(sort: \Conference.createdAt, order: .reverse)
    private var conferences: [Conference]

    @State private var showingNewNote = false
    @State private var showingSignIn = false

    struct Group: Identifiable {
        let conference: Conference?
        let notes: [Note]
        var id: String { conference?.id.uuidString ?? "other" }
    }

    /// Build the section list. `allConferences` keeps conferences visible even
    /// when all their notes are archived (or no notes exist yet). Sort order:
    /// most-recent note timestamp descending, with conference name as a stable
    /// tiebreaker; ungrouped notes always last.
    static func partition(notes: [Note], allConferences: [Conference] = []) -> [Group] {
        var byConferenceId: [UUID: (Conference, [Note])] = [:]
        for conf in allConferences {
            byConferenceId[conf.id] = (conf, [])
        }
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
        groups.sort { a, b in
            let aDate = a.notes.map(\.timestamp).max() ?? a.conference?.createdAt ?? .distantPast
            let bDate = b.notes.map(\.timestamp).max() ?? b.conference?.createdAt ?? .distantPast
            if aDate != bDate { return aDate > bDate }
            // Stable tiebreaker on conference name.
            return (a.conference?.name ?? "") < (b.conference?.name ?? "")
        }
        if !ungrouped.isEmpty {
            groups.append(Group(conference: nil, notes: ungrouped))
        }
        return groups
    }

    private var groups: [Group] { Self.partition(notes: notes, allConferences: conferences) }

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
                .sheet(isPresented: $showingSignIn) {
                    SignInView { showingSignIn = false }
                        .interactiveDismissDisabled()
                }
                .task {
                    // Prompt for sign-in at launch when no token is cached.
                    if await AuthService.shared.isSignedIn() == false {
                        showingSignIn = true
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
                    if let conference = group.conference {
                        Section {
                            // Conference acts as a tappable row above its
                            // talks. List section headers strip gestures from
                            // their content, so the conference link lives
                            // inside the section as a regular row instead.
                            NavigationLink(value: conference) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conference.name)
                                            .font(.headline)
                                        if group.notes.isEmpty {
                                            Text("No active talks")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("\(group.notes.count) talk\(group.notes.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            ForEach(group.notes) { note in
                                NavigationLink(value: note) {
                                    NoteRow(note: note)
                                }
                            }
                        }
                    } else {
                        Section("Other") {
                            ForEach(group.notes) { note in
                                NavigationLink(value: note) {
                                    NoteRow(note: note)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
