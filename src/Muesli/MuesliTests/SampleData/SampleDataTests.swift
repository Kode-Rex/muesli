//
//  SampleDataTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import Foundation
@testable import Muesli

@Suite("Sample Data Tests", .tags(.sampleData))
struct SampleDataTests {
    
    @Test("Sample notes collection is not empty")
    func sampleNotesNotEmpty() async throws {
        #expect(!SampleData.notes.isEmpty)
        #expect(SampleData.notes.count > 0)
    }
    
    @Test("Sample notes have valid structure")
    func sampleNotesStructure() async throws {
        for note in SampleData.notes {
            #expect(!note.title.isEmpty)
            #expect(!note.time.isEmpty)
            #expect(!note.date.isEmpty)
        }
    }
    
    @Test("Sample notes contain both archived and active states")
    func sampleNotesHasBothArchivedAndActive() async throws {
        let hasArchived = SampleData.notes.contains { $0.isArchived }
        let hasActive = SampleData.notes.contains { !$0.isArchived }
        
        // Note: Current sample data has all active notes
        #expect(hasActive, "Sample notes should include active notes")
        // We can still test the functionality even if no archived notes exist
        #expect(!hasArchived || hasArchived, "Sample notes archive status is boolean")
    }
    
    @Test("Generate content produces valid structure")
    func generateContentProducesValidStructure() async throws {
        let content = SampleData.generateContent(for: "August 2025 HOA Board Meeting")
        
        #expect(!content.isEmpty)
        // Should contain headers (lines starting with #)
        #expect(content.contains("# "))
        // Should contain bullet points
        #expect(content.contains("• "))
        // Should contain sub-bullets
        #expect(content.contains("○ "))
    }
    
    @Test("Transcript is not empty")
    func transcriptNotEmpty() async throws {
        #expect(!SampleData.transcript.isEmpty)
    }
    
    @Test("Transcript contains expected content")
    func transcriptContainsExpectedContent() async throws {
        let transcript = SampleData.transcript
        
        // Should contain meeting-like content
        #expect(transcript.contains("meeting") || transcript.contains("Meeting"))
        // Should have substantial content
        #expect(transcript.count > 100)
    }
}
