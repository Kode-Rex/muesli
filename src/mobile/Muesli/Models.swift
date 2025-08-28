//
//  Models.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var timestamp: Date
    var conferenceName: String?
    var sessionType: String // "meeting", "session", "note"
    var isArchived: Bool
    var audioFilePath: String? // Local path to audio file
    var transcriptionStatus: String // "none", "pending", "processing", "completed", "failed"
    var duration: TimeInterval? // Recording duration in seconds
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        timestamp: Date = Date(),
        conferenceName: String? = nil,
        sessionType: String = "note",
        isArchived: Bool = false,
        audioFilePath: String? = nil,
        transcriptionStatus: String = "none",
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.conferenceName = conferenceName
        self.sessionType = sessionType
        self.isArchived = isArchived
        self.audioFilePath = audioFilePath
        self.transcriptionStatus = transcriptionStatus
        self.duration = duration
    }
    
    // Computed properties for UI display
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US") // Ensure AM/PM format for tests
        return formatter.string(from: timestamp)
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM yyyy" // Include year for tests
        formatter.locale = Locale(identifier: "en_US") // Ensure consistent format
        return formatter.string(from: timestamp)
    }
    
    var durationString: String {
        guard let duration = duration else { return "00:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var hasAudio: Bool {
        return audioFilePath != nil
    }
    
    var needsTranscription: Bool {
        return hasAudio && (transcriptionStatus == "none" || transcriptionStatus == "failed")
    }
    
    var isTranscribing: Bool {
        return transcriptionStatus == "processing"
    }
}

// MARK: - Note Model Extensions and Utilities
// All note functionality is now handled through SwiftData and the DataService
