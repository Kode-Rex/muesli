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

@Suite("Note Model Tests", .tags(.unit))
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

    @Test("Note userNotes defaults to empty string")
    func noteUserNotesDefault() async throws {
        let note = Note(
            title: "Test",
            content: "Content",
            sessionType: "note"
        )

        #expect(note.userNotes == "")
    }

    @Test("Note userNotes can be set and persists")
    func noteUserNotesPersistence() async throws {
        let note = Note(
            title: "Test",
            content: "Transcript content",
            sessionType: "note"
        )

        let userNotes = "Remember to follow up\nSchedule meeting"
        note.userNotes = userNotes

        #expect(note.userNotes == userNotes)
        #expect(note.content == "Transcript content") // Verify content is separate
    }

    @Test("Note can have both content and userNotes")
    func noteBothContentAndUserNotes() async throws {
        let note = Note(
            title: "Test",
            content: "This is the transcript",
            userNotes: "These are my notes"
        )

        #expect(note.content == "This is the transcript")
        #expect(note.userNotes == "These are my notes")
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
        let longContent = String(repeating: "This is a very long content string. ", count: 1_000)
        let note = Note(
            title: "Long Content Test",
            content: longContent,
            conferenceName: "Performance Conf",
            sessionType: "Load Testing"
        )

        #expect(note.content == longContent)
        #expect(note.content.count > 30_000) // Ensure it's actually long
    }

    @Test("Note audio properties work correctly")
    func noteAudioPropertiesWorkCorrectly() async throws {
        let noteWithAudio = Note(
            title: "Audio Note",
            content: "This note has audio",
            audioFilePath: "recording_123.m4a",
            transcriptionStatus: "completed",
            duration: 120.5
        )

        #expect(noteWithAudio.hasAudio == true)
        #expect(noteWithAudio.audioFilePath == "recording_123.m4a")
        #expect(noteWithAudio.transcriptionStatus == "completed")
        #expect(noteWithAudio.duration == 120.5)
        #expect(noteWithAudio.durationString == "02:00")

        let noteWithoutAudio = Note(
            title: "Text Note",
            content: "This note has no audio"
        )

        #expect(noteWithoutAudio.hasAudio == false)
        #expect(noteWithoutAudio.audioFilePath == nil)
        #expect(noteWithoutAudio.transcriptionStatus == "none")
        #expect(noteWithoutAudio.duration == nil)
    }

    @Test("Note transcription status properties work correctly")
    func noteTranscriptionStatusPropertiesWorkCorrectly() async throws {
        let needsTranscriptionNote = Note(
            title: "Pending Note",
            content: "Content",
            audioFilePath: "recording.m4a",
            transcriptionStatus: "none"
        )

        #expect(needsTranscriptionNote.needsTranscription == true)
        #expect(needsTranscriptionNote.isTranscribing == false)

        let failedTranscriptionNote = Note(
            title: "Failed Note",
            content: "Content",
            audioFilePath: "recording.m4a",
            transcriptionStatus: "failed"
        )

        #expect(failedTranscriptionNote.needsTranscription == true)
        #expect(failedTranscriptionNote.isTranscribing == false)

        let processingNote = Note(
            title: "Processing Note",
            content: "Content",
            audioFilePath: "recording.m4a",
            transcriptionStatus: "processing"
        )

        #expect(processingNote.needsTranscription == false)
        #expect(processingNote.isTranscribing == true)

        let completedNote = Note(
            title: "Completed Note",
            content: "Transcribed content",
            audioFilePath: "recording.m4a",
            transcriptionStatus: "completed"
        )

        #expect(completedNote.needsTranscription == false)
        #expect(completedNote.isTranscribing == false)

        let noAudioNote = Note(
            title: "Text Only",
            content: "No audio file",
            transcriptionStatus: "none"
        )

        #expect(noAudioNote.needsTranscription == false)
        #expect(noAudioNote.isTranscribing == false)
    }

    @Test("Note duration formatting works correctly")
    func noteDurationFormattingWorksCorrectly() async throws {
        let testCases: [(TimeInterval, String)] = [
            (0, "00:00"),
            (30, "00:30"),
            (60, "01:00"),
            (90, "01:30"),
            (3_600, "60:00"),
            (3_661, "61:01"),
            (120.7, "02:00") // Should truncate fractional seconds
        ]

        for (duration, expected) in testCases {
            let note = Note(
                title: "Duration Test",
                content: "Test content",
                duration: duration
            )

            #expect(note.durationString == expected)
        }
    }

    @Test("Note speaker defaults to nil")
    func noteSpeakerDefault() async throws {
        let note = Note(title: "Talk")
        #expect(note.speaker == nil)
    }

    @Test("Note speaker can be set")
    func noteSpeakerSet() async throws {
        let note = Note(title: "Talk", speaker: "Sarah Chen")
        #expect(note.speaker == "Sarah Chen")
    }

    @Test("Note conference relationship is nil by default")
    func noteConferenceDefault() async throws {
        let note = Note(title: "Talk")
        #expect(note.conference == nil)
    }

    @Test("Note can be attached to Conference")
    func noteConferenceRelationship() async throws {
        let schema = Schema([Note.self, Photo.self, Conference.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let conf = Conference(name: "DataSummit 2026")
        let note = Note(title: "Talk")
        note.conference = conf
        context.insert(conf)
        context.insert(note)
        try context.save()

        #expect(note.conference?.name == "DataSummit 2026")
        #expect(conf.notes.count == 1)
        #expect(conf.notes.first?.title == "Talk")
    }
}

// MARK: - Test Tags
extension Tag {
    @Tag static var model: Self
    @Tag static var contentUtilities: Self
    @Tag static var contentParsing: Self
    @Tag static var utilities: Self
    @Tag static var swiftData: Self
    @Tag static var swiftdata: Self
    @Tag static var transcription: Self
    @Tag static var recording: Self
    @Tag static var network: Self
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var ui: Self
    @Tag static var views: Self
    @Tag static var performance: Self
}
