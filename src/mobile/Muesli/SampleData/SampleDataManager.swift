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
        let conferences = generateSampleConferences()
        conferences.forEach(context.insert)

        let dataSummit = conferences[0]
        let devWorld = conferences[1]
        let sampleNotes = generateSampleNotes(dataSummit: dataSummit, devWorld: devWorld)

        for note in sampleNotes {
            context.insert(note)
        }

        do {
            try context.save()
            AppLogger.shared.dataSuccess(
                "Sample Data",
                details: "Seeded \(conferences.count) conferences and \(sampleNotes.count) notes"
            )
        } catch {
            AppLogger.shared.dataError("Sample Data", error: error)
        }
    }

    static func generateSampleConferences() -> [Conference] {
        let cal = Calendar.current
        let dataSummit = Conference(
            name: "DataSummit 2026",
            location: "San Francisco, CA",
            startDate: cal.date(from: DateComponents(year: 2_026, month: 5, day: 10)),
            endDate: cal.date(from: DateComponents(year: 2_026, month: 5, day: 12)),
            conferenceDescription: "Annual data and ML conference"
        )
        let devWorld = Conference(
            name: "DevWorld 2026",
            location: "Austin, TX",
            startDate: cal.date(from: DateComponents(year: 2_026, month: 3, day: 14)),
            endDate: cal.date(from: DateComponents(year: 2_026, month: 3, day: 16)),
            conferenceDescription: "Developer conference covering web, mobile, and platforms"
        )
        return [dataSummit, devWorld]
    }

    static func generateSampleNotes(dataSummit: Conference, devWorld: Conference) -> [Note] {
        let baseTime = Date()

        return [
            // DataSummit 2026 talks (3)
            Note(
                title: "The three pillars of data infra",
                content: "Storage, compute, and discoverability. Sarah walked through how DataSummit's flagship team rebuilt their lake-house on these primitives.",
                timestamp: baseTime.addingTimeInterval(-3_600),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_three_pillars.m4a",
                transcriptionStatus: "completed",
                duration: 2_400,
                speaker: "Sarah Chen",
                conference: dataSummit
            ).withSeededBackendSessionId(),
            Note(
                title: "Streaming at planet scale",
                content: "Devon's deep dive on multi-region streaming, exactly-once semantics, and the operational realities they hit at year three.",
                timestamp: baseTime.addingTimeInterval(-7_200),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_streaming.m4a",
                transcriptionStatus: "completed",
                duration: 2_700,
                speaker: "Devon Park",
                conference: dataSummit
            ).withSeededBackendSessionId(),
            Note(
                title: "Embeddings for everything",
                content: "Hina's plenary on using embeddings as the universal interface across retrieval, ranking, and dedup.",
                timestamp: baseTime.addingTimeInterval(-90_000),
                conferenceName: "DataSummit 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_embeddings.m4a",
                transcriptionStatus: "completed",
                duration: 3_000,
                speaker: "Hina Yoshida",
                conference: dataSummit
            ).withSeededBackendSessionId(),

            // DevWorld 2026 talks (2)
            Note(
                title: "SwiftUI performance audit",
                content: "A pragmatic tour of Instruments for SwiftUI, view identity, and the diff cost of large lists.",
                timestamp: baseTime.addingTimeInterval(-5_184_000),
                conferenceName: "DevWorld 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: "sample_swiftui_perf.m4a",
                transcriptionStatus: "completed",
                duration: 1_800,
                speaker: "Aiden Reyes",
                conference: devWorld
            ).withSeededBackendSessionId(),
            Note(
                title: "Edge runtimes in practice",
                content: "What works, what doesn't, and the boring middle of running production services at the edge.",
                timestamp: baseTime.addingTimeInterval(-5_270_400),
                conferenceName: "DevWorld 2026",
                sessionType: "session",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0,
                speaker: "Priya Iyer",
                conference: devWorld
            ).withSeededBackendSessionId(),

            // Ungrouped notes (preserved for non-conference flows)
            Note(
                title: "Team Standup",
                content: "Discussed current sprint progress. John is working on the API integration, Sarah is finishing the UI components.",
                timestamp: baseTime.addingTimeInterval(-1_800),
                conferenceName: nil,
                sessionType: "meeting",
                isArchived: false,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            ),
            Note(
                title: "Old Project Notes",
                content: "Legacy project documentation that's no longer active but kept for reference.",
                timestamp: baseTime.addingTimeInterval(-604_800),
                conferenceName: nil,
                sessionType: "documentation",
                isArchived: true,
                audioFilePath: nil,
                transcriptionStatus: "none",
                duration: 0
            )
        ]
    }

    // MARK: - Utility Methods

    static func clearAllData(context: ModelContext) {
        do {
            try context.delete(model: ChatMessage.self)
            try context.delete(model: ChatThread.self)
            try context.delete(model: Note.self)
            try context.delete(model: Conference.self)
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

private extension Note {
    /// Sample-data helper: assigns a deterministic backendSessionId so chat
    /// against a backend that has the same seed rows works without a real
    /// blend round-trip. Production notes get this from BlendOrchestrator.
    func withSeededBackendSessionId() -> Note {
        self.backendSessionId = self.id
        return self
    }
}

#endif
