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
        
        let personalNotes = ContentUtilities.extractPersonalNotes(from: content)
        
        #expect(!personalNotes.isEmpty)
        #expect(personalNotes.contains { $0.contains("email") } || personalNotes.contains { $0.contains("proposal") })
    }
    
    @Test("Extract personal notes handles no personal content")
    func extractPersonalNotesHandlesNoPersonalContent() async throws {
        let content = """
        ## Meeting Notes
        - General discussion point
        - Another general point
        """
        
        let personalNotes = ContentUtilities.extractPersonalNotes(from: content)
        #expect(personalNotes.isEmpty)
    }
    
    @Test("Extract personal notes handles empty content")
    func extractPersonalNotesHandlesEmptyContent() async throws {
        let personalNotes = ContentUtilities.extractPersonalNotes(from: "")
        #expect(personalNotes.isEmpty)
    }
}
