//
//  TestSetup.swift
//  MuesliTests
//
//  Centralized test setup and utilities
//

import Foundation
import SwiftData
import Testing
@testable import Muesli

/// Provides test setup utilities and mock data for all tests
struct TestSetup {
    
    // MARK: - Test Data Creation
    
    static func createTestNote(
        title: String = "Test Note",
        content: String = "Test content for unit testing",
        conferenceName: String? = nil,
        sessionType: String = "note",
        isArchived: Bool = false,
        audioFilePath: String? = nil,
        transcriptionStatus: String = "none",
        duration: TimeInterval = 0
    ) -> Note {
        return Note(
            title: title,
            content: content,
            timestamp: Date(),
            conferenceName: conferenceName,
            sessionType: sessionType,
            isArchived: isArchived,
            audioFilePath: audioFilePath,
            transcriptionStatus: transcriptionStatus,
            duration: duration
        )
    }
    
    static func createMultipleTestNotes(count: Int = 3) -> [Note] {
        return (1...count).map { index in
            createTestNote(
                title: "Test Note \(index)",
                content: "Test content for note \(index)",
                sessionType: index % 2 == 0 ? "meeting" : "note",
                isArchived: index > count / 2
            )
        }
    }
    
    // MARK: - SwiftData Test Container
    
    static func createTestContainer() throws -> ModelContainer {
        let schema = Schema([Note.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    @MainActor
    static func setupTestDataInContainer(_ container: ModelContainer) throws {
        let context = container.mainContext
        let testNotes = createMultipleTestNotes(count: 5)
        
        for note in testNotes {
            context.insert(note)
        }
        
        try context.save()
    }
    
    // MARK: - Service Initialization
    
    /// Ensures all singletons are properly initialized for testing
    static func initializeServicesForTesting() async {
        // Initialize services that might be accessed by tests
        _ = AudioRecordingManager.shared
        _ = NetworkMonitor.shared
        _ = PerformanceMonitor.shared
        _ = TranscriptionService.shared
        
        // Wait a moment for async initialization to complete
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    // MARK: - Test Audio File
    
    static func createTestAudioFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test-audio.m4a")
        
        // Create a minimal empty file for testing
        try Data().write(to: audioURL)
        
        return audioURL
    }
    
    // MARK: - Mock Network Responses
    
    static func mockTranscriptionResponse() -> [String: Any] {
        return [
            "transcript": "This is a test transcription response from the mock API.",
            "confidence": 0.95,
            "metadata": [
                "model": "nova-2",
                "language": "en-US",
                "duration": 120.0
            ]
        ]
    }
    
    // MARK: - Test Constants
    
    struct TestConstants {
        static let defaultTimeout: TimeInterval = 5.0
        static let testContent = "This is test content for unit testing purposes. It contains enough text to test various parsing and processing functions."
        static let testTranscript = "Hello world this is a test transcription with some sample content for testing purposes."
        static let testConferenceName = "Test Conference 2024"
        static let testSessionTypes = ["note", "meeting", "brainstorm", "voice-note"]
    }
    
    // MARK: - Cleanup
    
    static func cleanup() throws {
        // Clean up any temporary test files
        let tempDir = FileManager.default.temporaryDirectory
        let testFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        
        for file in testFiles where file.pathExtension == "m4a" && file.lastPathComponent.contains("test") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - Test Extensions

extension Note {
    /// Creates a note with test data for unit testing
    static func testNote(
        title: String = "Test Note",
        content: String = TestSetup.TestConstants.testContent,
        audioPath: String? = nil,
        transcriptionStatus: String = "completed"
    ) -> Note {
        return TestSetup.createTestNote(
            title: title,
            content: content,
            audioFilePath: audioPath,
            transcriptionStatus: transcriptionStatus
        )
    }
}

// MARK: - Testing Tags
// Tags are defined in NoteModelTests.swift to avoid redeclaration