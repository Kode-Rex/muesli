//
//  DataService.swift
//  Muesli
//
//  Created by AI Assistant on 8/25/25.
//

import Foundation
import SwiftData
import SwiftUI

// Environment key for DataService
private struct DataServiceKey: EnvironmentKey {
    static let defaultValue: DataService? = nil
}

extension EnvironmentValues {
    var dataService: DataService? {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}

@Observable
class DataService {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Note Operations

    func createNote(
        title: String,
        content: String = "",
        conferenceName: String? = nil,
        sessionType: String = "note"
    ) throws {
        try PerformanceMonitor.shared.measure(operation: "Create Note") {
            let note = Note(
                title: title,
                content: content,
                timestamp: Date(),
                conferenceName: conferenceName,
                sessionType: sessionType,
                isArchived: false
            )

            modelContext.insert(note)
            try modelContext.save()
            AppLogger.shared.dataSuccess("Create Note", details: "Title: \(title)")
        }
    }

    func updateNote(_ note: Note, title: String? = nil, content: String? = nil) throws {
        try PerformanceMonitor.shared.measure(operation: "Update Note") {
            if let title = title {
                note.title = title
            }
            if let content = content {
                note.content = content
            }
            try modelContext.save()
            AppLogger.shared.dataSuccess("Update Note", details: "Title: \(note.title)")
        }
    }

    func archiveNote(_ note: Note) throws {
        note.isArchived = true
        try modelContext.save()
    }

    func unarchiveNote(_ note: Note) throws {
        note.isArchived = false
        try modelContext.save()
    }

    func deleteNote(_ note: Note) throws {
        modelContext.delete(note)
        try modelContext.save()
    }

    // MARK: - Query Operations

    func fetchActiveNotes() -> [Note] {
        return PerformanceMonitor.shared.measure(operation: "Fetch Active Notes") {
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            do {
                let notes = try modelContext.fetch(descriptor)
                AppLogger.shared.dataSuccess("Fetch Active Notes", details: "Count: \(notes.count)")
                return notes
            } catch {
                AppLogger.shared.dataError("Fetch Active Notes", error: error)
                return []
            }
        }
    }

    func fetchArchivedNotes() -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let notes = try modelContext.fetch(descriptor)
            AppLogger.shared.dataSuccess("Fetch Archived Notes", details: "Count: \(notes.count)")
            return notes
        } catch {
            AppLogger.shared.dataError("Fetch Archived Notes", error: error)
            return []
        }
    }

    func searchNotes(query: String, includeArchived: Bool = false) -> [Note] {
        return PerformanceMonitor.shared.measure(operation: "Search Notes") {
            let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !searchQuery.isEmpty else {
                return includeArchived ? fetchAllNotes() : fetchActiveNotes()
            }

            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate { note in
                    (note.title.localizedStandardContains(searchQuery) ||
                        note.content.localizedStandardContains(searchQuery) ||
                        (note.conferenceName?.localizedStandardContains(searchQuery) ?? false)) &&
                        (includeArchived || !note.isArchived)
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            do {
                let results = try modelContext.fetch(descriptor)
                AppLogger.shared.searchOperation(query: searchQuery, resultCount: results.count, includeArchived: includeArchived)
                return results
            } catch {
                AppLogger.shared.dataError("Search Notes", error: error, details: "Query: '\(searchQuery)'")
                return []
            }
        }
    }

    func fetchAllNotes() -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let notes = try modelContext.fetch(descriptor)
            AppLogger.shared.dataSuccess("Fetch All Notes", details: "Count: \(notes.count)")
            return notes
        } catch {
            AppLogger.shared.dataError("Fetch All Notes", error: error)
            return []
        }
    }

    // MARK: - Statistics

    func getArchivedCount() -> Int {
        fetchArchivedNotes().count
    }

    func getTotalNotesCount() -> Int {
        fetchAllNotes().count
    }

    // MARK: - Sample Data Seeding

    func seedSampleDataIfNeeded() throws {
        let existingNotes = fetchAllNotes()

        // Only seed if there are no existing notes
        guard existingNotes.isEmpty else { return }

        let sampleNotes = [
            Note(
                title: "Welcome to Muesli",
                content: """
                # Getting Started

                • Create new notes by tapping the "New" button
                • Organize notes by type: note, meeting, or session
                • Archive notes you no longer need
                • Search through all your notes instantly

                # Features

                ○ Real-time sync across devices
                ○ Markdown-style formatting support
                ○ Archive and search functionality
                ○ Conference and meeting organization

                # Next Steps

                • Explore the app interface
                • Create your first note
                • Try the search functionality
                """,
                timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                sessionType: "note"
            ),
            Note(
                title: "Sample Meeting Notes",
                content: """
                # Project Kickoff Meeting

                • Discussed project timeline and milestones
                • Assigned roles and responsibilities
                • Reviewed budget and resource allocation

                # Action Items

                ○ Schedule weekly check-ins
                ○ Set up project repository
                ○ Create initial documentation
                ○ Send meeting summary to stakeholders

                # Next Meeting

                • Date: Next Friday at 2:00 PM
                • Focus: Technical architecture review
                • Attendees: Full development team
                """,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                conferenceName: "Project Alpha",
                sessionType: "meeting"
            )
        ]

        for note in sampleNotes {
            modelContext.insert(note)
        }

        try modelContext.save()
    }
}
