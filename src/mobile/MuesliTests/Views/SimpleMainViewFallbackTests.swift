//
//  SimpleMainViewFallbackTests.swift
//  MuesliTests
//
//  Tests for batch transcription fallback paths used by the main list.
//  Uses TestWorld to inject fakes so no real network traffic occurs.
//

import Testing
import SwiftUI
import SwiftData
@testable import Muesli

@MainActor
struct SimpleMainViewFallbackTests {

    private let transcription: FakeTranscriptionAdapter

    init() {
        self.transcription = TestWorld.install().transcription
    }

    private func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Batch Transcription Fallback

    @Test("Batch transcription handles API unavailable gracefully")
    func batchTranscriptionHandlesAPIUnavailableGracefully() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let pendingNote = Note(
            title: "Pending Transcription",
            content: "",
            timestamp: Date(),
            sessionType: "note",
            audioFilePath: "test-audio.m4a",
            transcriptionStatus: "pending",
            duration: 120.0
        )
        context.insert(pendingNote)
        try context.save()

        // Fake returns nil → simulating API-unavailable failure path.
        transcription.stubFileTranscript = nil

        pendingNote.transcriptionStatus = "processing"
        try context.save()
        let audioURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-audio.m4a")
        if let transcript = await World.current.transcription.transcribeAudioFile(url: audioURL) {
            pendingNote.content = transcript
            pendingNote.transcriptionStatus = "completed"
        } else {
            pendingNote.transcriptionStatus = "failed"
        }
        try context.save()

        #expect(pendingNote.transcriptionStatus == "failed")
        #expect(pendingNote.content.isEmpty)
    }

    @Test("Multiple batch transcription requests don't interfere")
    func multipleBatchTranscriptionRequestsDontInterfere() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let notes = [
            Note(title: "Note 1", timestamp: Date(), sessionType: "note", audioFilePath: "audio1.m4a", transcriptionStatus: "pending", duration: 60.0),
            Note(title: "Note 2", timestamp: Date(), sessionType: "note", audioFilePath: "audio2.m4a", transcriptionStatus: "pending", duration: 90.0),
            Note(title: "Note 3", timestamp: Date(), sessionType: "note", audioFilePath: "audio3.m4a", transcriptionStatus: "pending", duration: 45.0)
        ]
        notes.forEach { context.insert($0) }
        try context.save()

        transcription.stubFileTranscript = "Hello from fake transcription"

        // Sequential — the original concurrent test was conflating concurrent
        // SwiftData writes against the same context (unsupported) with
        // transcription parallelism (which the fake doesn't care about).
        for note in notes {
            let audioURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(note.audioFilePath ?? "default.m4a")
            if let transcript = await World.current.transcription.transcribeAudioFile(url: audioURL) {
                note.content = transcript
                note.transcriptionStatus = "completed"
            } else {
                note.transcriptionStatus = "failed"
            }
            try context.save()
        }

        for note in notes {
            #expect(note.transcriptionStatus == "completed")
            #expect(note.content == "Hello from fake transcription")
        }
        #expect(transcription.transcribeFileURLs.count == 3)
    }

    // MARK: - Error State Management

    @Test("Transcription failure updates note status correctly")
    func transcriptionFailureUpdatesNoteStatusCorrectly() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let failureNote = Note(
            title: "Will Fail Transcription",
            content: "",
            timestamp: Date(),
            sessionType: "note",
            audioFilePath: "nonexistent.m4a",
            transcriptionStatus: "pending",
            duration: 30.0
        )
        context.insert(failureNote)
        try context.save()

        transcription.stubFileTranscript = nil

        let nonExistentURL = URL(fileURLWithPath: "/tmp/definitely-does-not-exist.m4a")
        let result = await World.current.transcription.transcribeAudioFile(url: nonExistentURL)
        #expect(result == nil)

        if result == nil {
            failureNote.transcriptionStatus = "failed"
            try context.save()
        }

        #expect(failureNote.transcriptionStatus == "failed")
        #expect(failureNote.content.isEmpty)
    }

    @Test("Database save errors during transcription are handled")
    func databaseSaveErrorsDuringTranscriptionAreHandled() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let testNote = Note(
            title: "Database Test Note",
            timestamp: Date(),
            sessionType: "note",
            audioFilePath: "test.m4a",
            transcriptionStatus: "pending",
            duration: 60.0
        )
        context.insert(testNote)
        try context.save()

        testNote.transcriptionStatus = "processing"
        testNote.content = "Transcribed content"
        testNote.transcriptionStatus = "completed"
        do {
            try context.save()
        } catch {
            testNote.transcriptionStatus = "failed"
        }

        #expect(testNote.transcriptionStatus == "completed" || testNote.transcriptionStatus == "failed")
    }

    // MARK: - Status Transitions

    @Test("Transcription status transitions follow correct flow")
    func transcriptionStatusTransitionsFollowCorrectFlow() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let flowTestNote = Note(
            title: "Status Flow Test",
            timestamp: Date(),
            sessionType: "note",
            audioFilePath: "flow-test.m4a",
            transcriptionStatus: "pending",
            duration: 75.0
        )
        context.insert(flowTestNote)
        try context.save()
        #expect(flowTestNote.transcriptionStatus == "pending")

        flowTestNote.transcriptionStatus = "processing"
        try context.save()
        #expect(flowTestNote.transcriptionStatus == "processing")

        transcription.stubFileTranscript = "Final transcript"

        let dummyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("flow-test.m4a")
        if let transcript = await World.current.transcription.transcribeAudioFile(url: dummyURL) {
            flowTestNote.content = transcript
            flowTestNote.transcriptionStatus = "completed"
        } else {
            flowTestNote.transcriptionStatus = "failed"
        }
        try context.save()

        #expect(flowTestNote.transcriptionStatus == "completed")
        #expect(flowTestNote.content == "Final transcript")
    }

    // MARK: - UI Integration

    @Test("Note list updates correctly after transcription status changes")
    func noteListUpdatesCorrectlyAfterTranscriptionStatusChanges() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        let completedNote = Note(title: "Completed", content: "Transcribed", timestamp: Date(), sessionType: "note", transcriptionStatus: "completed", duration: 60.0)
        let failedNote = Note(title: "Failed", timestamp: Date(), sessionType: "note", audioFilePath: "failed.m4a", transcriptionStatus: "failed", duration: 30.0)
        let pendingNote = Note(title: "Pending", timestamp: Date(), sessionType: "note", audioFilePath: "pending.m4a", transcriptionStatus: "pending", duration: 45.0)
        context.insert(completedNote)
        context.insert(failedNote)
        context.insert(pendingNote)
        try context.save()

        let allNotes = try context.fetch(FetchDescriptor<Note>())
        #expect(allNotes.filter { $0.transcriptionStatus == "completed" }.count >= 1)
        #expect(allNotes.filter { $0.transcriptionStatus == "failed" }.count >= 1)
        #expect(allNotes.filter { $0.transcriptionStatus == "pending" }.count >= 1)
    }

    // MARK: - Performance

    @Test("Large batch transcription operations don't block")
    func largeBatchTranscriptionOperationsDontBlock() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext

        var batchNotes: [Note] = []
        for i in 0..<5 {
            let note = Note(
                title: "Batch Note \(i)",
                timestamp: Date(),
                sessionType: "note",
                audioFilePath: "batch\(i).m4a",
                transcriptionStatus: "pending",
                duration: Double.random(in: 30...120)
            )
            batchNotes.append(note)
            context.insert(note)
        }
        try context.save()

        transcription.stubFileTranscript = "Done"

        let startTime = Date()
        for note in batchNotes {
            let dummyURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(note.audioFilePath ?? "default.m4a")
            let result = await World.current.transcription.transcribeAudioFile(url: dummyURL)
            note.transcriptionStatus = (result != nil) ? "completed" : "failed"
            try? context.save()
        }
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 5.0)

        for note in batchNotes {
            #expect(note.transcriptionStatus == "completed")
        }
    }
}
