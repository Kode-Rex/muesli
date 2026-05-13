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

    @State private var showingNewNote = false

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
                            Text("Other").font(.headline)
                        }
                    }
                }
            }
        }
    }
}
