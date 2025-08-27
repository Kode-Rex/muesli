//
//  AppConstants.swift
//  Muesli
//
//  Application constants and configuration values
//

import Foundation
import AVFoundation

struct AppConstants {
    
    // MARK: - Timing Constants
    struct Timing {
        static let recordingTimerInterval: TimeInterval = 0.1
        static let networkTimeoutInterval: TimeInterval = 30.0
        static let healthCheckTimeout: TimeInterval = 2.0
        static let transcriptionProcessTimeout: TimeInterval = 300.0
    }
    
    // MARK: - Audio Constants
    struct Audio {
        static let defaultSampleRate: Double = 44100.0
        static let bitRate: Int = 64000
        static let numberOfChannels: Int = 1
        static let audioQuality: AVAudioQuality = .high
        static let fileExtension: String = "m4a"
        static let contentType: String = "audio/mp4"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let defaultPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let cornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 44
        static let recordingButtonSize: CGFloat = 100
    }
    
    // MARK: - Performance Constants
    struct Performance {
        static let maxCachedOperations: Int = 100
        static let logRetentionDays: Int = 7
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Transcription Status
    enum TranscriptionStatus: String, CaseIterable {
        case none = "none"
        case pending = "pending" 
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        
        var displayName: String {
            switch self {
            case .none: return "No Transcription"
            case .pending: return "Pending"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
    }
    
    // MARK: - Session Types
    enum SessionType: String, CaseIterable {
        case note = "note"
        case meeting = "meeting"
        case brainstorm = "brainstorm"
        case voiceNote = "voice-note"
        case interview = "interview"
        case lecture = "lecture"
        
        var displayName: String {
            switch self {
            case .note: return "Note"
            case .meeting: return "Meeting"
            case .brainstorm: return "Brainstorm"
            case .voiceNote: return "Voice Note"
            case .interview: return "Interview"
            case .lecture: return "Lecture"
            }
        }
        
        var icon: String {
            switch self {
            case .note: return "note.text"
            case .meeting: return "person.3"
            case .brainstorm: return "lightbulb"
            case .voiceNote: return "mic"
            case .interview: return "questionmark.circle"
            case .lecture: return "graduationcap"
            }
        }
    }
    
    // MARK: - File Paths
    struct FilePaths {
        static let documentsDirectory = "Documents"
        static let audioDirectory = "Audio"
        static let logsDirectory = "Logs"
    }
    
    // MARK: - Validation
    struct Validation {
        static let minTitleLength: Int = 1
        static let maxTitleLength: Int = 100
        static let maxContentLength: Int = 50000
        static let minRecordingDuration: TimeInterval = 1.0
        static let maxRecordingDuration: TimeInterval = 7200.0 // 2 hours
    }
}

// MARK: - User Defaults Keys
extension AppConstants {
    struct UserDefaultsKeys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let preferredSessionType = "preferredSessionType"
        static let autoTranscriptionEnabled = "autoTranscriptionEnabled"
        static let lastAppVersion = "lastAppVersion"
    }
}

// MARK: - Notification Names
extension AppConstants {
    struct NotificationNames {
        static let recordingStarted = Notification.Name("recordingStarted")
        static let recordingStopped = Notification.Name("recordingStopped")
        static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
        static let networkStatusChanged = Notification.Name("networkStatusChanged")
    }
}