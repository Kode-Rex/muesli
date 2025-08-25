//
//  NoteModelTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("Note Model Tests", .tags(.model))
struct NoteModelTests {
    
    @Test("Note initialization with all properties")
    func noteInitialization() async throws {
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
    
    @Test("Note archive toggle functionality")
    func noteArchiveToggle() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        #expect(note.isArchived == false)
        
        note.isArchived = true
        #expect(note.isArchived == true)
        
        note.isArchived = false
        #expect(note.isArchived == false)
    }
    
    @Test("Note time string formatting")
    func noteTimeString() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        let timeString = note.timeString
        #expect(!timeString.isEmpty)
        // Should contain either AM or PM
        #expect(timeString.contains("AM") || timeString.contains("PM"))
    }
    
    @Test("Note date string formatting")
    func noteDateString() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            conferenceName: "Conf",
            sessionType: "Session"
        )
        
        let dateString = note.dateString
        #expect(!dateString.isEmpty)
        // Should contain current year
        let currentYear = Calendar.current.component(.year, from: Date())
        #expect(dateString.contains(String(currentYear)))
    }
    
    @Test("Note handles unicode content")
    func noteHandlesUnicodeContent() async throws {
        let unicodeContent = "Test with émojis 🚀 and spëcial characters"
        let note = Note(
            title: "Unicode Test",
            content: unicodeContent,
            conferenceName: "Unicode Conf",
            sessionType: "Testing"
        )
        
        #expect(note.content == unicodeContent)
        #expect(note.title == "Unicode Test")
    }
    
    @Test("Note handles long content")
    func noteHandlesLongContent() async throws {
        let longContent = String(repeating: "This is a very long content string. ", count: 1000)
        let note = Note(
            title: "Long Content Test",
            content: longContent,
            conferenceName: "Performance Conf",
            sessionType: "Load Testing"
        )
        
        #expect(note.content == longContent)
        #expect(note.content.count > 30000) // Ensure it's actually long
    }
}

// MARK: - Test Tags
extension Tag {
    @Tag static var model: Self
    @Tag static var contentUtilities: Self
    @Tag static var contentParsing: Self
    @Tag static var utilities: Self
    @Tag static var swiftData: Self
}
