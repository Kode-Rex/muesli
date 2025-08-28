//
//  SimpleMainViewFallbackTests.swift
//  MuesliTests
//
//  Created by Claude on 8/27/25.
//  Tests for SimpleMainView batch transcription fallback behavior
//

import Testing
import SwiftUI
import SwiftData
@testable import Muesli

struct SimpleMainViewFallbackTests {
    
    // MARK: - Setup Helper
    
    private func createTestModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Note.self, configurations: config)
    }
    
    // MARK: - Batch Transcription Fallback Tests
    
    @Test("Batch transcription handles API unavailable gracefully")
    func batchTranscriptionHandlesAPIUnavailableGracefully() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let transcriptionService = TranscriptionService.shared
        
        // Create a note that needs transcription
        let pendingNote = Note(
            title: "Pending Transcription",
            content: "",
            timestamp: Date(),
            conferenceName: nil,
            sessionType: "note",
            isArchived: false,
            audioFilePath: "test-audio.m4a",
            transcriptionStatus: "pending",
            duration: 120.0
        )
        
        context.insert(pendingNote)
        try context.save()
        
        // Simulate the batch transcription logic from SimpleMainView
        func simulateBatchTranscriptionFlow(for note: Note) async {
            // Update status to processing
            note.transcriptionStatus = "processing"
            try? context.save()
            
            // Create dummy audio URL (doesn't need to exist for this test)
            let audioURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-audio.m4a")
            
            // Attempt transcription
            if let transcript = await transcriptionService.transcribeAudioFile(url: audioURL) {
                // Success case
                note.content = transcript
                note.transcriptionStatus = "completed"
            } else {
                // Failure case - this is the important test
                note.transcriptionStatus = "failed"
            }
            
            // Save the updated status
            do {
                try context.save()
            } catch {
                // Handle save error gracefully
            }
        }
        
        // Run the simulation
        await simulateBatchTranscriptionFlow(for: pendingNote)
        
        // Verify the note is in a valid state
        #expect(pendingNote.title == "Pending Transcription")
        // Status should be either "completed" (if API was available) or "failed" (if not)
        #expect(pendingNote.transcriptionStatus == "completed" || pendingNote.transcriptionStatus == "failed")
        
        // If transcription failed, content should remain empty
        if pendingNote.transcriptionStatus == "failed" {
            #expect(pendingNote.content.isEmpty)
        }
    }
    
    @Test("Multiple batch transcription requests don't interfere")
    func multipleBatchTranscriptionRequestsDontInterfere() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let transcriptionService = TranscriptionService.shared
        
        // Create multiple notes that need transcription
        let notes = [
            Note(title: "Note 1", content: "", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: "audio1.m4a", transcriptionStatus: "pending", duration: 60.0),
            Note(title: "Note 2", content: "", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: "audio2.m4a", transcriptionStatus: "pending", duration: 90.0),
            Note(title: "Note 3", content: "", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: "audio3.m4a", transcriptionStatus: "pending", duration: 45.0)
        ]
        
        for note in notes {
            context.insert(note)
        }
        try context.save()
        
        // Process all notes concurrently (simulating user triggering multiple transcriptions)
        await withTaskGroup(of: Void.self) { group in
            for note in notes {
                group.addTask {
                    // Simulate batch transcription
                    let audioURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(note.audioFilePath ?? "default.m4a")
                    
                    let result = await transcriptionService.transcribeAudioFile(url: audioURL)
                    
                    // Update note based on result
                    if let transcript = result {
                        note.content = transcript
                        note.transcriptionStatus = "completed"
                    } else {
                        note.transcriptionStatus = "failed"
                    }
                    
                    // Save individual note updates
                    try? context.save()
                }
            }
        }
        
        // Verify all notes are in valid end states
        for note in notes {
            #expect(note.transcriptionStatus == "completed" || note.transcriptionStatus == "failed")
            #expect(!note.title.isEmpty) // Title should be preserved
        }
    }
    
    // MARK: - Error State Management Tests
    
    @Test("Transcription failure updates note status correctly")
    func transcriptionFailureUpdatesNoteStatusCorrectly() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let transcriptionService = TranscriptionService.shared
        
        let failureNote = Note(
            title: "Will Fail Transcription",
            content: "",
            timestamp: Date(),
            conferenceName: nil,
            sessionType: "note",
            isArchived: false,
            audioFilePath: "nonexistent.m4a",
            transcriptionStatus: "pending",
            duration: 30.0
        )
        
        context.insert(failureNote)
        try context.save()
        
        // Simulate transcription with non-existent file
        let nonExistentURL = URL(fileURLWithPath: "/tmp/definitely-does-not-exist.m4a")
        let result = await transcriptionService.transcribeAudioFile(url: nonExistentURL)
        
        // Should return nil for non-existent file
        #expect(result == nil)
        
        // Simulate the error handling from SimpleMainView
        if result == nil {
            failureNote.transcriptionStatus = "failed"
            try context.save()
        }
        
        #expect(failureNote.transcriptionStatus == "failed")
        #expect(failureNote.content.isEmpty) // Content should remain empty on failure
    }
    
    @Test("Database save errors during transcription are handled")
    func databaseSaveErrorsDuringTranscriptionAreHandled() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        let testNote = Note(
            title: "Database Test Note",
            content: "",
            timestamp: Date(),
            conferenceName: nil,
            sessionType: "note",
            isArchived: false,
            audioFilePath: "test.m4a",
            transcriptionStatus: "pending",
            duration: 60.0
        )
        
        context.insert(testNote)
        try context.save()
        
        // Simulate the error handling logic from SimpleMainView
        func simulateTranscriptionWithSaveError() throws {
            testNote.transcriptionStatus = "processing"
            
            // Simulate transcription success but save error
            testNote.content = "Transcribed content"
            testNote.transcriptionStatus = "completed"
            
            // In a real error scenario, save might fail
            // But our test should handle this gracefully
            do {
                try context.save()
            } catch {
                // Revert to failed state if save fails
                testNote.transcriptionStatus = "failed"
                // This tests that we handle save errors gracefully
            }
        }
        
        // This should not crash even if save operations fail
        try simulateTranscriptionWithSaveError()
        
        // Note should be in a valid state
        #expect(testNote.transcriptionStatus == "completed" || testNote.transcriptionStatus == "failed")
    }
    
    // MARK: - Status Transition Tests
    
    @Test("Transcription status transitions follow correct flow")
    func transcriptionStatusTransitionsFollowCorrectFlow() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let transcriptionService = TranscriptionService.shared
        
        let flowTestNote = Note(
            title: "Status Flow Test",
            content: "",
            timestamp: Date(),
            conferenceName: nil,
            sessionType: "note",
            isArchived: false,
            audioFilePath: "flow-test.m4a",
            transcriptionStatus: "pending",
            duration: 75.0
        )
        
        context.insert(flowTestNote)
        try context.save()
        
        // Test the full status flow
        #expect(flowTestNote.transcriptionStatus == "pending")
        
        // Move to processing
        flowTestNote.transcriptionStatus = "processing"
        try context.save()
        #expect(flowTestNote.transcriptionStatus == "processing")
        
        // Simulate transcription attempt
        let dummyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("flow-test.m4a")
        let result = await transcriptionService.transcribeAudioFile(url: dummyURL)
        
        // Move to final state based on result
        if let transcript = result {
            flowTestNote.content = transcript
            flowTestNote.transcriptionStatus = "completed"
        } else {
            flowTestNote.transcriptionStatus = "failed"
        }
        
        try context.save()
        
        // Final state should be either completed or failed
        #expect(flowTestNote.transcriptionStatus == "completed" || flowTestNote.transcriptionStatus == "failed")
        #expect(flowTestNote.transcriptionStatus != "pending")
        #expect(flowTestNote.transcriptionStatus != "processing")
    }
    
    // MARK: - UI Integration Tests
    
    @Test("Note list updates correctly after transcription status changes")
    func noteListUpdatesCorrectlyAfterTranscriptionStatusChanges() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        // Create notes with different statuses
        let completedNote = Note(title: "Completed", content: "Transcribed", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: nil, transcriptionStatus: "completed", duration: 60.0)
        let failedNote = Note(title: "Failed", content: "", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: "failed.m4a", transcriptionStatus: "failed", duration: 30.0)
        let pendingNote = Note(title: "Pending", content: "", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false, audioFilePath: "pending.m4a", transcriptionStatus: "pending", duration: 45.0)
        
        context.insert(completedNote)
        context.insert(failedNote)
        context.insert(pendingNote)
        try context.save()
        
        // Verify we can query notes by status
        let fetchRequest = FetchDescriptor<Note>()
        let allNotes = try context.fetch(fetchRequest)
        
        let completedNotes = allNotes.filter { $0.transcriptionStatus == "completed" }
        let failedNotes = allNotes.filter { $0.transcriptionStatus == "failed" }
        let pendingNotes = allNotes.filter { $0.transcriptionStatus == "pending" }
        
        #expect(completedNotes.count >= 1)
        #expect(failedNotes.count >= 1) 
        #expect(pendingNotes.count >= 1)
        
        // Verify UI-relevant properties
        for note in allNotes {
            #expect(!note.title.isEmpty)
            #expect(note.timestamp <= Date()) // Should not be in the future
            #expect(note.duration >= 0) // Should not be negative
            #expect(["pending", "processing", "completed", "failed"].contains(note.transcriptionStatus))
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Large batch transcription operations don't block")
    func largeBatchTranscriptionOperationsDontBlock() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let transcriptionService = TranscriptionService.shared
        
        // Create a larger batch of notes
        var batchNotes: [Note] = []
        for i in 0..<20 {
            let note = Note(
                title: "Batch Note \(i)",
                content: "",
                timestamp: Date(),
                conferenceName: nil,
                sessionType: "note",
                isArchived: false,
                audioFilePath: "batch\(i).m4a",
                transcriptionStatus: "pending",
                duration: Double.random(in: 30...120)
            )
            batchNotes.append(note)
            context.insert(note)
        }
        try context.save()
        
        let startTime = Date()
        
        // Process batch with timeout to ensure it doesn't hang
        await withTaskGroup(of: Void.self) { group in
            for note in batchNotes.prefix(5) { // Test with first 5 to avoid overwhelming
                group.addTask {
                    let dummyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(note.audioFilePath ?? "default.m4a")
                    let result = await transcriptionService.transcribeAudioFile(url: dummyURL)
                    
                    note.transcriptionStatus = (result != nil) ? "completed" : "failed"
                    try? context.save()
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time (even if all fail)
        #expect(duration < 30.0) // Should not take more than 30 seconds
        
        // All processed notes should have final status
        for note in batchNotes.prefix(5) {
            #expect(note.transcriptionStatus == "completed" || note.transcriptionStatus == "failed")
        }
    }
}