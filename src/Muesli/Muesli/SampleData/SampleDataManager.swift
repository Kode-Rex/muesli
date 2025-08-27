//
//  SampleDataManager.swift
//  Muesli
//
//  Manages sample data for development and testing
//

import Foundation
import SwiftData

#if DEBUG
struct SampleDataManager {
    
    // MARK: - Sample Data Generation
    
    static func seedDatabase(context: ModelContext) {
        let sampleNotes = generateSampleNotes()
        
        for note in sampleNotes {
            context.insert(note)
        }
        
        do {
            try context.save()
            AppLogger.shared.dataSuccess("Sample Data", details: "Seeded \(sampleNotes.count) sample notes")
        } catch {
            AppLogger.shared.dataError("Sample Data", error: error)
        }
    }
    
    static func generateSampleNotes() -> [Note] {
        let baseTime = Date()
        
        return [
            // Basic notes
            Note(
                title: "Team Standup",
                content: "Discussed current sprint progress. John is working on the API integration, Sarah is finishing the UI components. Need to review the deployment pipeline by Friday.",
                timestamp: baseTime.addingTimeInterval(-3600), // 1 hour ago
                conferenceName: nil,
                sessionType: "meeting",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            ),
            
            Note(
                title: "Feature Ideas",
                content: "Brainstormed some interesting features:\n• Dark mode toggle\n• Export functionality\n• Collaboration features\n• Voice notes integration",
                timestamp: baseTime.addingTimeInterval(-7200), // 2 hours ago
                conferenceName: nil,
                sessionType: "brainstorm",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            ),
            
            Note(
                title: "Client Feedback",
                content: "Client loved the new interface design. Requested some minor adjustments to the color scheme and font sizing. Overall very positive response.",
                timestamp: baseTime.addingTimeInterval(-86400), // 1 day ago
                conferenceName: nil,
                sessionType: "client-meeting",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "completed",
                duration: 1800 // 30 minutes
            ),
            
            // Note with transcription
            Note(
                title: "Architecture Review",
                content: "Reviewed the current system architecture. The microservices approach is working well, but we need to optimize the database queries. Consider implementing caching layer.",
                timestamp: baseTime.addingTimeInterval(-172800), // 2 days ago
                conferenceName: "Tech Architecture",
                sessionType: "technical-review",
                isArchived: false,
                audioFilePath: "sample_architecture_review.m4a",
                transcriptionStatus: "completed",
                duration: 2400 // 40 minutes
            ),
            
            // Archived note
            Note(
                title: "Old Project Notes",
                content: "Legacy project documentation that's no longer active but kept for reference. Contains important historical decisions and rationale.",
                timestamp: baseTime.addingTimeInterval(-604800), // 1 week ago
                conferenceName: nil,
                sessionType: "documentation",
                isArchived: true,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            ),
            
            // Note with failed transcription
            Note(
                title: "Quick Voice Note",
                content: "This was recorded as a voice note but transcription failed. Needs to be reprocessed.",
                timestamp: baseTime.addingTimeInterval(-1800), // 30 minutes ago
                conferenceName: nil,
                sessionType: "voice-note",
                isArchived: false,
                audioFilePath: "quick_voice_note.m4a",
                transcriptionStatus: "failed",
                duration: 120 // 2 minutes
            )
        ]
    }
    
    // MARK: - Utility Methods
    
    static func clearAllData(context: ModelContext) {
        do {
            try context.delete(model: Note.self)
            try context.save()
            AppLogger.shared.dataSuccess("Sample Data", details: "Cleared all data")
        } catch {
            AppLogger.shared.dataError("Sample Data Clear", error: error)
        }
    }
    
    static func reseedDatabase(context: ModelContext) {
        clearAllData(context: context)
        seedDatabase(context: context)
    }
}

// MARK: - Debug Menu Integration

extension SampleDataManager {
    static func createDebugMenuActions(context: ModelContext) -> [(String, () -> Void)] {
        return [
            ("Reseed Sample Data", { reseedDatabase(context: context) }),
            ("Clear All Data", { clearAllData(context: context) }),
            ("Add More Notes", { seedDatabase(context: context) })
        ]
    }
}

#endif