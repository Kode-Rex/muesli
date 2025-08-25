//
//  UtilitiesTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import Foundation
@testable import Muesli

@Suite("Utilities Tests", .tags(.utilities))
struct UtilitiesTests {
    
    @Test("Extract personal notes finds action items")
    func extractPersonalNotesFindsActionItems() async throws {
        let content = """
        ## Meeting Notes
        - General discussion point
        - [Personal] Send follow-up email
        - Another general point
        - [Action] Review the proposal
        """
        
        let personalNotes = SampleData.extractPersonalNotes(from: content)
        
        #expect(personalNotes.count == 2)
        #expect(personalNotes.contains("Send follow-up email"))
        #expect(personalNotes.contains("Review the proposal"))
    }
    
    @Test("Extract personal notes handles no personal content")
    func extractPersonalNotesHandlesNoPersonalContent() async throws {
        let content = """
        ## Meeting Notes
        - General discussion point
        - Another general point
        """
        
        let personalNotes = SampleData.extractPersonalNotes(from: content)
        #expect(personalNotes.isEmpty)
    }
    
    @Test("Extract personal notes handles empty content")
    func extractPersonalNotesHandlesEmptyContent() async throws {
        let personalNotes = SampleData.extractPersonalNotes(from: "")
        #expect(personalNotes.isEmpty)
    }
}
