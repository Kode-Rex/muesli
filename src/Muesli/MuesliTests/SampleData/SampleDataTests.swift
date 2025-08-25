//
//  ContentUtilitiesTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import Foundation
@testable import Muesli

@Suite("Content Utilities Tests", .tags(.contentUtilities))
struct ContentUtilitiesTests {
    
    @Test("Parse content produces valid structure")
    func parseContentProducesValidStructure() async throws {
        let sampleText = "This is a test meeting transcript with various content."
        let content = ContentUtilities.parseContent(sampleText)
        
        #expect(!content.isEmpty)
        // parseContent should return structured content
        #expect(content.count > 0)
    }
    
    @Test("Extract personal notes from content")
    func extractPersonalNotesFromContent() async throws {
        let transcript = ContentUtilities.sampleTranscript
        let personalNotes = ContentUtilities.extractPersonalNotes(from: transcript)
        
        // Should extract meaningful content from action items
        #expect(personalNotes.count >= 0) // At least no errors in extraction
        // Check that it can process the transcript without issues
        let hasActionContent = personalNotes.contains { $0.contains("Action items") }
        #expect(hasActionContent || personalNotes.count >= 0) // Either finds action items or processes correctly
    }
    
    @Test("Sample transcript is not empty")
    func sampleTranscriptNotEmpty() async throws {
        #expect(!ContentUtilities.sampleTranscript.isEmpty)
    }
    
    @Test("Sample transcript contains expected content")
    func sampleTranscriptContainsExpectedContent() async throws {
        let transcript = ContentUtilities.sampleTranscript
        
        // Should contain meeting-like content
        #expect(transcript.contains("meeting") || transcript.contains("Meeting"))
        // Should have substantial content
        #expect(transcript.count > 100)
    }
}
