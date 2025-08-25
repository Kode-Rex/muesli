//
//  DataService.swift
//  Muesli
//
//  Created by AI Assistant on 8/25/25.
//

import Foundation
import SwiftData
import SwiftUI

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
    }
    
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil) throws {
        if let title = title {
            note.title = title
        }
        if let content = content {
            note.content = content
        }
        try modelContext.save()
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
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching active notes: \(error)")
            return []
        }
    }
    
    func fetchArchivedNotes() -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching archived notes: \(error)")
            return []
        }
    }
    
    func searchNotes(query: String, includeArchived: Bool = false) -> [Note] {
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
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error searching notes: \(error)")
            return []
        }
    }
    
    func fetchAllNotes() -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching all notes: \(error)")
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

// MARK: - Environment Key
struct DataServiceKey: EnvironmentKey {
    static let defaultValue: DataService? = nil
}

extension EnvironmentValues {
    var dataService: DataService? {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}
