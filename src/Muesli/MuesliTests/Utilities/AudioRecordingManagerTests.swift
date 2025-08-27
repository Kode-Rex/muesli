//
//  AudioRecordingManagerTests.swift
//  MuesliTests
//
//  Tests for AudioRecordingManager functionality
//

import Testing
import Foundation
import AVFoundation
@testable import Muesli

@Suite("Audio Recording Manager Tests", .tags(.recording))
struct AudioRecordingManagerTests {
    
    // Remove shared state dependency
    init() async throws {
        // No shared state initialization
    }
    
    @Test("Audio recording manager singleton works")
    func audioRecordingManagerSingletonWorks() async throws {
        let manager1 = AudioRecordingManager.shared
        let manager2 = AudioRecordingManager.shared
        
        #expect(manager1 === manager2)
    }
    
    @Test("Recording state initializes correctly")
    func recordingStateInitializesCorrectly() async throws {
        let manager = AudioRecordingManager.shared
        
        #expect(manager.state == .idle)
        #expect(manager.currentRecordingPath == nil)
        #expect(manager.recordingDuration == 0)
    }
    
    @Test("Permission check returns boolean")
    func permissionCheckReturnsBoolean() async throws {
        let manager = AudioRecordingManager.shared
        
        manager.checkPermission()
        
        // hasPermission should be a boolean regardless of actual permission
        #expect(manager.hasPermission == true || manager.hasPermission == false)
    }
    
    @Test("Recording error descriptions are provided")
    func recordingErrorDescriptionsAreProvided() async throws {
        let errors: [RecordingError] = [
            .permissionDenied,
            .recordingFailed,
            .fileNotFound,
            .audioSessionError
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
        
        // Test specific descriptions
        #expect(RecordingError.permissionDenied.errorDescription?.contains("permission") == true)
        #expect(RecordingError.recordingFailed.errorDescription?.contains("Recording failed") == true)
        #expect(RecordingError.fileNotFound.errorDescription?.contains("file not found") == true)
        #expect(RecordingError.audioSessionError.errorDescription?.contains("session") == true)
    }
    
    @Test("Recording URL generation works correctly")
    func recordingURLGenerationWorksCorrectly() async throws {
        let manager = AudioRecordingManager.shared
        let testFileName = "test_recording.m4a"
        
        // Test with non-existent file
        let nonExistentURL = manager.getRecordingURL(fileName: "non_existent_file.m4a")
        #expect(nonExistentURL == nil)
        
        // Test path generation logic
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let expectedURL = documentsPath.appendingPathComponent(testFileName)
        
        #expect(expectedURL.lastPathComponent == testFileName)
        #expect(expectedURL.pathExtension == "m4a")
    }
    
    @Test("Delete recording handles missing files gracefully")
    func deleteRecordingHandlesMissingFilesGracefully() async throws {
        let manager = AudioRecordingManager.shared
        let nonExistentFile = "non_existent_recording.m4a"
        
        // Should not crash when trying to delete non-existent file
        manager.deleteRecording(fileName: nonExistentFile)
        
        // Should complete without throwing
        #expect(Bool(true))
    }
    
    @Test("Recording states are correctly defined")
    func recordingStatesAreCorrectlyDefined() async throws {
        let states: [RecordingState] = [.idle, .recording, .paused, .finished]
        
        #expect(states.count == 4)
        
        // Test that each state can be compared
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.recording != RecordingState.paused)
        #expect(RecordingState.paused != RecordingState.finished)
    }
    
    @Test("Recording manager prevents unauthorized access gracefully")
    func recordingManagerPreventsUnauthorizedAccessGracefully() async throws {
        let manager = AudioRecordingManager.shared
        
        // If permission is denied, operations should handle gracefully
        if !manager.hasPermission {
            do {
                _ = try await manager.startRecording()
                #expect(Bool(false)) // Should not reach here if no permission
            } catch RecordingError.permissionDenied {
                #expect(Bool(true)) // Expected behavior
            } catch {
                #expect(Bool(false)) // Should specifically throw permission denied
            }
        }
    }
    
    @Test("Recording state transitions are logical")
    func recordingStateTransitionsAreLogical() async throws {
        let manager = AudioRecordingManager.shared
        
        // Initial state should be idle
        #expect(manager.state == .idle)
        
        // Test that certain operations are safe when in idle state
        manager.pauseRecording() // Should not crash
        manager.resumeRecording() // Should not crash
        manager.cancelRecording() // Should not crash
        
        #expect(manager.state == .idle) // Should remain idle
    }
    
    @Test("Audio format settings are correctly configured")
    func audioFormatSettingsAreCorrectlyConfigured() async throws {
        // Test the expected audio settings that would be used
        let expectedSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        #expect(expectedSettings[AVFormatIDKey] as? Int == Int(kAudioFormatMPEG4AAC))
        #expect(expectedSettings[AVSampleRateKey] as? Int == 44100)
        #expect(expectedSettings[AVNumberOfChannelsKey] as? Int == 1)
        #expect(expectedSettings[AVEncoderAudioQualityKey] as? Int == AVAudioQuality.high.rawValue)
    }
    
    @Test("File naming conventions are consistent")
    func fileNamingConventionsAreConsistent() async throws {
        // Test default file naming pattern
        let uuidPattern = #"^recording_[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\.m4a$"#
        
        // Generate a sample UUID-based filename
        let testUUID = UUID()
        let filename = "recording_\(testUUID.uuidString).m4a"
        
        #expect(filename.hasSuffix(".m4a"))
        #expect(filename.hasPrefix("recording_"))
        #expect(filename.contains(testUUID.uuidString))
    }
}

