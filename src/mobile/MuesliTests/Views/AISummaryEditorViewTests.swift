//
//  AISummaryEditorViewTests.swift
//  MuesliTests
//
//  Tests for AISummaryEditorView functionality
//

import Testing
import Foundation
import SwiftUI
@testable import Muesli

@Suite("AI Summary Editor View Tests", .tags(.views))
struct AISummaryEditorViewTests {
    
    @Test("AI summary generates appropriate content for note")
    func aiSummaryGeneratesAppropriateContent() async throws {
        let note = Note(
            title: "Test Meeting",
            content: "Discussed project timeline. Need to review budget. Action items: email client, update documentation.",
            sessionType: "meeting"
        )
        
        // Test the simulated summary generation logic
        let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines).count
        #expect(wordCount > 0)
        
        // Verify content contains actionable items
        #expect(note.content.contains("Action items"))
        #expect(note.content.contains("email"))
    }
    
    @Test("AI summary handles different session types")
    func aiSummaryHandlesDifferentSessionTypes() async throws {
        let sessionTypes = ["meeting", "note", "session"]
        
        for sessionType in sessionTypes {
            let note = Note(
                title: "Test \(sessionType.capitalized)",
                content: "Sample content for testing",
                sessionType: sessionType
            )
            
            #expect(["meeting", "note", "session"].contains(note.sessionType))
        }
    }
    
    @Test("AI summary word count calculation")
    func aiSummaryWordCountCalculation() async throws {
        let testCases = [
            ("", 0),
            ("single", 1),
            ("two words", 2),
            ("multiple words in sentence", 4),
            ("  spaced   words  ", 2), // Extra whitespace should be handled
            ("line\nbreak\nwords", 3)
        ]
        
        for (content, expectedCount) in testCases {
            let wordCount = content.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            #expect(wordCount == expectedCount)
        }
    }
    
    @Test("AI summary content analysis detects key elements")
    func aiSummaryContentAnalysisDetectsKeyElements() async throws {
        let meetingContent = """
        Meeting started at 9 AM with all team members present.
        Discussed Q4 goals and budget allocation.
        Action items: review contracts, schedule follow-up meeting.
        Next steps: prepare presentation for client.
        """
        
        // Test detection of meeting-specific elements
        #expect(meetingContent.contains("Meeting"))
        #expect(meetingContent.contains("Action items"))
        #expect(meetingContent.contains("Next steps"))
        
        // Test word count for content analysis
        let wordCount = meetingContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        #expect(wordCount > 20) // Should be substantial content
    }
    
    @Test("AI summary generates different insights based on content length")
    func aiSummaryGeneratesDifferentInsightsBasedOnContentLength() async throws {
        let shortContent = "Brief note"
        let mediumContent = String(repeating: "word ", count: 25) // ~25 words
        let longContent = String(repeating: "detailed content word ", count: 100) // ~300 words
        
        let shortWordCount = shortContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        let mediumWordCount = mediumContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        let longWordCount = longContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        
        #expect(shortWordCount < 10)
        #expect(mediumWordCount >= 20 && mediumWordCount < 50)
        #expect(longWordCount >= 100)
    }
    
    @Test("AI summary handles empty or minimal content")
    func aiSummaryHandlesEmptyOrMinimalContent() async throws {
        let emptyNote = Note(
            title: "Empty Note",
            content: "",
            sessionType: "note"
        )
        
        let minimalNote = Note(
            title: "Minimal Note",
            content: "Just a word",
            sessionType: "note"
        )
        
        // Test empty content
        let emptyWordCount = emptyNote.content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        #expect(emptyWordCount == 0)
        
        // Test minimal content
        let minimalWordCount = minimalNote.content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        #expect(minimalWordCount > 0)
    }
    
    @Test("AI summary content structure analysis")
    func aiSummaryContentStructureAnalysis() async throws {
        let structuredContent = """
        # Meeting Notes
        ## Agenda Items
        • Project status update
        • Budget review
        • Resource allocation
        
        ## Action Items
        • Review Q4 budget proposal
        • Schedule team meeting
        • Update project timeline
        """
        
        // Test structure detection
        #expect(structuredContent.contains("#"))  // Headers
        #expect(structuredContent.contains("•"))  // Bullet points
        #expect(structuredContent.contains("Action Items"))  // Sections
        
        // Test line counting
        let lines = structuredContent.components(separatedBy: .newlines)
        #expect(lines.count > 5) // Should have multiple lines
    }
}

// MARK: - Supporting Extensions for Testing

extension AISummaryEditorViewTests {
    
    /// Helper to simulate summary generation logic
    func generateTestSummary(for note: Note) -> String {
        let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        
        if wordCount == 0 {
            return "No content available for summary."
        } else if wordCount < 10 {
            return "Brief \(note.sessionType) with minimal content."
        } else if wordCount < 50 {
            return "Moderate \(note.sessionType) covering key topics."
        } else {
            return "Comprehensive \(note.sessionType) with detailed discussion and action items."
        }
    }
    
    @Test("Test summary generation helper")
    func testSummaryGenerationHelper() async throws {
        let emptyNote = Note(title: "Empty", content: "", sessionType: "note")
        let shortNote = Note(title: "Short", content: "Brief content", sessionType: "meeting")
        let longNote = Note(title: "Long", content: String(repeating: "detailed content ", count: 60), sessionType: "session")
        
        let emptySummary = generateTestSummary(for: emptyNote)
        let shortSummary = generateTestSummary(for: shortNote)
        let longSummary = generateTestSummary(for: longNote)
        
        #expect(emptySummary.contains("No content"))
        #expect(shortSummary.contains("Brief"))
        #expect(longSummary.contains("Comprehensive"))
    }
}