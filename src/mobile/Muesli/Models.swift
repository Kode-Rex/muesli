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

    // SwiftData doesn't handle Optional arrays well, use empty array as default
    var imagePaths: [String] = [] // Array of local file paths to captured images

    var aiSummary: String? // AI-generated summary of the transcript
    var userNotes: String = "" // User's personal notes added during or after recording

    // Speaker shown in the augmented note view; user-provided or transcriber-derived.
    var speaker: String?

    // Blend pipeline outputs (populated post-stop)
    var transcript: String?
    var transcriptWordsJSON: Data?
    var blendedMarkdown: String?
    var blendCitationsJSON: Data?
    var chaptersJSON: Data?
    var blendStatusRaw: String = "idle"
    var blendError: String?
    var blendCostMicros: Int?
    var blendModelVersion: String?
    /// The UUID the backend assigned for this note's session (from
    /// `sessionsRepo.createSession`). Set by `BlendOrchestrator` once the
    /// upload + blend cycle starts; used by chat routes to address the
    /// backend's stored transcript / blended content. Nil for notes that
    /// haven't been through the blend pipeline yet.
    var backendSessionId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \Photo.note) var photos: [Photo] = []

    // Conference grouping. Replaces conferenceName at the read site;
    // conferenceName is retained for one release as a fallback.
    var conference: Conference?

    var blendStatus: BlendStatus {
        get { BlendStatus(rawValue: blendStatusRaw) ?? .idle }
        set { blendStatusRaw = newValue.rawValue }
    }

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
        duration: TimeInterval? = nil,
        imagePaths: [String] = [],
        aiSummary: String? = nil,
        userNotes: String = "",
        speaker: String? = nil,
        conference: Conference? = nil
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
        self.imagePaths = imagePaths
        self.aiSummary = aiSummary
        self.userNotes = userNotes
        self.speaker = speaker
        self.conference = conference
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

    var hasImages: Bool {
        return !imagePaths.isEmpty
    }

    var imageCount: Int {
        return imagePaths.count
    }

    /// Conference name preferring the `Conference` relationship over the
    /// legacy `conferenceName` string. New UI should always read this.
    /// `conferenceName` is retained for one release as a migration fallback.
    var resolvedConferenceName: String? {
        conference?.name ?? conferenceName
    }
}

// MARK: - Note Model Extensions and Utilities
// All note functionality is now handled through SwiftData and the DataService

enum BlendStatus: String, Codable {
    case idle, transcribing, transcribed, extracting, blending, complete, failed
}
