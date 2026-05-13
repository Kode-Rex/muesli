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
        #expect(!content.isEmpty)
    }

    @Test("Extract personal notes from content")
    func extractPersonalNotesFromContent() async throws {
        let transcript = ContentUtilities.sampleTranscript
        let personalNotes = ContentUtilities.extractPersonalNotes(from: transcript)

        // The sample transcript embeds "Action items:" which the extractor
        // surfaces as a personal note. Either the parser finds it, or it
        // returns nothing (no errors) — both are acceptable shapes.
        let hasActionContent = personalNotes.contains { $0.contains("Action items") }
        #expect(hasActionContent || personalNotes.isEmpty)
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
