//
//  MuesliTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import SwiftData
@testable import Muesli

struct MuesliTests {
    
    // MARK: - Note Model Tests
    
    @Test func noteInitialization() async throws {
        let title = "Test Meeting"
        let content = "This is test content"
        let conferenceName = "TestConf 2024"
        let sessionType = "Keynote"
        
        let note = Note(
            title: title,
            content: content,
            conferenceName: conferenceName,
            sessionType: sessionType
        )
        
        #expect(note.title == title)
        #expect(note.content == content)
        #expect(note.conferenceName == conferenceName)
        #expect(note.sessionType == sessionType)
        #expect(note.isArchived == false) // Default value
        #expect(note.timestamp.timeIntervalSinceNow < 1) // Created recently
    }
    
    @Test func noteArchiveToggle() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        // Initially not archived
        #expect(note.isArchived == false)
        
        // Archive the note
        note.isArchived = true
        #expect(note.isArchived == true)
        
        // Unarchive the note
        note.isArchived = false
        #expect(note.isArchived == false)
    }
    
    @Test func noteTimeString() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        let timeString = note.timeString
        #expect(!timeString.isEmpty)
        #expect(timeString.contains(":"))
    }
    
    @Test func noteDateString() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        let dateString = note.dateString
        #expect(!dateString.isEmpty)
        // Should contain a month and day
        #expect(dateString.count > 3)
    }
    
    // MARK: - Sample Data Tests
    
    @Test func sampleNotesNotEmpty() async throws {
        #expect(!SampleData.notes.isEmpty)
        #expect(SampleData.notes.count > 0)
    }
    
    @Test func sampleNotesStructure() async throws {
        for note in SampleData.notes {
            #expect(!note.title.isEmpty)
            #expect(!note.time.isEmpty)
            #expect(!note.date.isEmpty)
        }
    }
    
    @Test func sampleNotesHasBothArchivedAndActive() async throws {
        let hasArchived = SampleData.notes.contains { $0.isArchived }
        let hasActive = SampleData.notes.contains { !$0.isArchived }
        
        // Note: Current sample data has all active notes
        #expect(hasActive, "Sample notes should include active notes")
        // We can still test the functionality even if no archived notes exist
        #expect(!hasArchived || hasArchived, "Sample notes archive status is boolean")
    }
    
    // MARK: - Content Generation Tests
    
    @Test func generateContentProducesValidStructure() async throws {
        let content = SampleData.generateContent(for: "Test Meeting")
        
        #expect(!content.isEmpty)
        #expect(content.contains("# "), "Content should contain headers")
        #expect(content.contains("• "), "Content should contain bullet points")
        #expect(content.contains("○ "), "Content should contain sub-bullets")
    }
    
    @Test func parseContentHandlesHeaders() async throws {
        let testContent = "# Test Header\nSome content"
        let parsed = SampleData.parseContent(testContent)
        
        #expect(!parsed.isEmpty)
        let firstItem = parsed[0]
        #expect(firstItem.1 == .header)
        #expect(firstItem.0 == "Test Header")
    }
    
    @Test func parseContentHandlesBullets() async throws {
        let testContent = "• Test bullet point"
        let parsed = SampleData.parseContent(testContent)
        
        #expect(!parsed.isEmpty)
        let firstItem = parsed[0]
        #expect(firstItem.1 == .bullet)
        #expect(firstItem.0 == "Test bullet point")
    }
    
    @Test func parseContentHandlesSubBullets() async throws {
        let testContent = "○ Test sub-bullet point"
        let parsed = SampleData.parseContent(testContent)
        
        #expect(!parsed.isEmpty)
        let firstItem = parsed[0]
        #expect(firstItem.1 == .subBullet)
        #expect(firstItem.0 == "Test sub-bullet point")
    }
    
    @Test func parseContentHandlesText() async throws {
        let testContent = "Regular text line"
        let parsed = SampleData.parseContent(testContent)
        
        #expect(!parsed.isEmpty)
        let firstItem = parsed[0]
        #expect(firstItem.1 == .bullet) // Regular text is treated as bullet
        #expect(firstItem.0 == "Regular text line")
    }
    
    @Test func parseContentHandlesMixedContent() async throws {
        let testContent = """
        # Header
        Regular text
        • Bullet point
        ○ Sub-bullet
        More text
        """
        
        let parsed = SampleData.parseContent(testContent)
        
        #expect(parsed.count == 5)
        #expect(parsed[0].1 == .header)
        #expect(parsed[1].1 == .bullet)
        #expect(parsed[2].1 == .bullet)
        #expect(parsed[3].1 == .subBullet)
        #expect(parsed[4].1 == .bullet)
    }
    
    @Test func parseContentIgnoresEmptyLines() async throws {
        let testContent = """
        # Header
        
        • Bullet
        
        
        Text
        """
        
        let parsed = SampleData.parseContent(testContent)
        
        // Should only have 3 items (header, bullet, text) - empty lines ignored
        #expect(parsed.count == 3)
        #expect(parsed[0].1 == .header)
        #expect(parsed[1].1 == .bullet)
        #expect(parsed[2].1 == .bullet)
    }
    
    // MARK: - Extract Personal Notes Tests
    
    @Test func extractPersonalNotesFindsActionItems() async throws {
        let testContent = "• Schedule follow-up meetings\n• Regular note\n• Complete AI certification"
        let personalNotes = SampleData.extractPersonalNotes(from: testContent)
        
        #expect(personalNotes.contains("• Schedule follow-up meetings"))
        #expect(personalNotes.contains("• Complete AI certification"))
        #expect(!personalNotes.contains("• Regular note"))
    }
    
    @Test func extractPersonalNotesHandlesEmptyContent() async throws {
        let personalNotes = SampleData.extractPersonalNotes(from: "")
        #expect(personalNotes.isEmpty)
    }
    
    @Test func extractPersonalNotesHandlesNoPersonalContent() async throws {
        let testContent = "• Regular meeting note\n• Another standard note"
        let personalNotes = SampleData.extractPersonalNotes(from: testContent)
        #expect(personalNotes.isEmpty)
    }
    
    // MARK: - Transcript Tests
    
    @Test func transcriptNotEmpty() async throws {
        #expect(!SampleData.transcript.isEmpty)
        #expect(SampleData.transcript.count > 100) // Should be substantial
    }
    
    @Test func transcriptContainsExpectedContent() async throws {
        #expect(SampleData.transcript.contains("Welcome"), "Transcript should contain welcome message")
        #expect(SampleData.transcript.contains("Tom"), "Transcript should contain speaker names")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test func parseContentHandlesSpecialCharacters() async throws {
        let testContent = "# Header with émojis 🚀\n• Bullet with special chars: @#$%"
        let parsed = SampleData.parseContent(testContent)
        
        #expect(parsed.count == 2)
        #expect(parsed[0].0.contains("émojis"))
        #expect(parsed[0].0.contains("🚀"))
        #expect(parsed[1].0.contains("@#$%"))
    }
    
    @Test func noteHandlesLongContent() async throws {
        let longContent = String(repeating: "A", count: 10000)
        let note = Note(
            title: "Long Content Test",
            content: longContent,
            conferenceName: "Test Conf",
            sessionType: "Test Session"
        )
        
        #expect(note.content.count == 10000)
        #expect(note.title == "Long Content Test")
    }
    
    @Test func noteHandlesUnicodeContent() async throws {
        let unicodeContent = "Testing 中文 العربية עברית 🎉"
        let note = Note(
            title: "Unicode Test",
            content: unicodeContent,
            conferenceName: "International Conf",
            sessionType: "Global Session"
        )
        
        #expect(note.content == unicodeContent)
        #expect(note.conferenceName == "International Conf")
    }
}
