//
//  SwiftDataTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("SwiftData Operation Tests", .tags(.swiftdata))
struct SwiftDataTests {
    
    private func createTestContainer() throws -> ModelContainer {
        return try TestSetup.createTestContainer()
    }
    
    @Test("Create and save note")
    @MainActor func createAndSaveNote() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let note = Note(
            title: "Test Note",
            content: "This is test content",
            conferenceName: "Test Conference",
            sessionType: "test"
        )
        
        context.insert(note)
        try context.save()
        
        // Verify note was saved
        let descriptor = FetchDescriptor<Note>()
        let savedNotes = try context.fetch(descriptor)
        
        #expect(savedNotes.count == 1)
        #expect(savedNotes.first?.title == "Test Note")
        #expect(savedNotes.first?.content == "This is test content")
    }
    
    @Test("Update existing note")
    @MainActor func updateExistingNote() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create initial note
        let note = Note(
            title: "Original Title",
            content: "Original content",
            conferenceName: nil,
            sessionType: "note"
        )
        
        context.insert(note)
        try context.save()
        
        // Update the note
        note.title = "Updated Title"
        note.content = "Updated content"
        try context.save()
        
        // Verify update
        let descriptor = FetchDescriptor<Note>()
        let savedNotes = try context.fetch(descriptor)
        
        #expect(savedNotes.count == 1)
        #expect(savedNotes.first?.title == "Updated Title")
        #expect(savedNotes.first?.content == "Updated content")
    }
    
    @Test("Archive and unarchive note")
    @MainActor func archiveAndUnarchiveNote() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let note = Note(
            title: "Test Note",
            content: "Test content",
            conferenceName: nil,
            sessionType: "note"
        )
        
        context.insert(note)
        try context.save()
        
        #expect(note.isArchived == false)
        
        // Archive the note
        note.isArchived = true
        try context.save()
        
        let archivedDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.isArchived }
        )
        let archivedNotes = try context.fetch(archivedDescriptor)
        #expect(archivedNotes.count == 1)
        
        // Unarchive the note
        note.isArchived = false
        try context.save()
        
        let activeDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { !$0.isArchived }
        )
        let activeNotes = try context.fetch(activeDescriptor)
        #expect(activeNotes.count == 1)
    }
    
    @Test("Delete note")
    @MainActor func deleteNote() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let note = Note(
            title: "Note to Delete",
            content: "This will be deleted",
            conferenceName: nil,
            sessionType: "note"
        )
        
        context.insert(note)
        try context.save()
        
        // Verify note exists
        let beforeDescriptor = FetchDescriptor<Note>()
        let beforeNotes = try context.fetch(beforeDescriptor)
        #expect(beforeNotes.count == 1)
        
        // Delete note
        context.delete(note)
        try context.save()
        
        // Verify note is deleted
        let afterDescriptor = FetchDescriptor<Note>()
        let afterNotes = try context.fetch(afterDescriptor)
        #expect(afterNotes.count == 0)
    }
    
    @Test("Search notes by title")
    @MainActor func searchNotesByTitle() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create test notes
        let notes = [
            Note(title: "Meeting Notes", content: "Important meeting", conferenceName: nil, sessionType: "note"),
            Note(title: "Project Planning", content: "Plan the project", conferenceName: nil, sessionType: "note"),
            Note(title: "Random Ideas", content: "Some random thoughts", conferenceName: nil, sessionType: "note")
        ]
        
        for note in notes {
            context.insert(note)
        }
        try context.save()
        
        // Search for notes containing "meeting"
        let searchDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.title.localizedStandardContains("Meeting")
            }
        )
        let searchResults = try context.fetch(searchDescriptor)
        
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.title == "Meeting Notes")
    }
    
    @Test("Search notes by content")
    @MainActor func searchNotesByContent() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create test notes
        let notes = [
            Note(title: "Note 1", content: "This contains special keyword", conferenceName: nil, sessionType: "note"),
            Note(title: "Note 2", content: "This is regular content", conferenceName: nil, sessionType: "note"),
            Note(title: "Note 3", content: "Another special keyword here", conferenceName: nil, sessionType: "note")
        ]
        
        for note in notes {
            context.insert(note)
        }
        try context.save()
        
        // Search for notes containing "special"
        let searchDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.content.localizedStandardContains("special")
            }
        )
        let searchResults = try context.fetch(searchDescriptor)
        
        #expect(searchResults.count == 2)
    }
    
    @Test("Filter active notes")
    @MainActor func filterActiveNotes() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        // Create mix of active and archived notes
        let notes = [
            Note(title: "Active 1", content: "Active note", conferenceName: nil, sessionType: "note"),
            Note(title: "Active 2", content: "Another active note", conferenceName: nil, sessionType: "note"),
            Note(title: "Archived 1", content: "Archived note", conferenceName: nil, sessionType: "note")
        ]
        
        notes[2].isArchived = true // Archive the third note
        
        for note in notes {
            context.insert(note)
        }
        try context.save()
        
        // Fetch only active notes
        let activeDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { !$0.isArchived }
        )
        let activeNotes = try context.fetch(activeDescriptor)
        
        #expect(activeNotes.count == 2)
        #expect(activeNotes.allSatisfy { !$0.isArchived })
    }
    
    @Test("Sort notes by timestamp")
    @MainActor func sortNotesByTimestamp() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let now = Date()
        let notes = [
            Note(title: "Newest", content: "Content", timestamp: now, conferenceName: nil, sessionType: "note", isArchived: false),
            Note(title: "Oldest", content: "Content", timestamp: now.addingTimeInterval(-3600), conferenceName: nil, sessionType: "note", isArchived: false),
            Note(title: "Middle", content: "Content", timestamp: now.addingTimeInterval(-1800), conferenceName: nil, sessionType: "note", isArchived: false)
        ]
        
        for note in notes {
            context.insert(note)
        }
        try context.save()
        
        // Fetch notes sorted by timestamp (newest first)
        let sortedDescriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let sortedNotes = try context.fetch(sortedDescriptor)
        
        #expect(sortedNotes.count == 3)
        #expect(sortedNotes[0].title == "Newest")
        #expect(sortedNotes[1].title == "Middle")
        #expect(sortedNotes[2].title == "Oldest")
    }
    
    @Test("Note time and date string formatting")
    @MainActor func noteTimeAndDateStringFormatting() async throws {
        let note = Note(
            title: "Test Note",
            content: "Test content",
            conferenceName: nil,
            sessionType: "note"
        )
        
        let timeString = note.timeString
        let dateString = note.dateString
        
        #expect(!timeString.isEmpty)
        #expect(!dateString.isEmpty)
        
        // Should contain AM or PM for time
        #expect(timeString.contains("AM") || timeString.contains("PM"))
        
        // Date should contain current year
        let currentYear = Calendar.current.component(.year, from: Date())
        #expect(dateString.contains(String(currentYear)))
    }
}

// Test tags are defined in NoteModelTests.swift to avoid redeclaration
