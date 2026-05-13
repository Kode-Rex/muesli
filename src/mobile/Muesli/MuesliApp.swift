//
//  MuesliApp.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

@main
struct MuesliApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Photo.self,
            Conference.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the error but continue with in-memory fallback
            AppLogger.shared.error("SwiftData container creation failed, using in-memory fallback", error: error)
            
            // Fallback to in-memory storage
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // Last resort - this should never happen
                AppLogger.shared.error("Critical: Even in-memory container failed", error: error)
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
    }()

    init() {
        TranscriptionOrchestrator.shared.setContainer(sharedModelContainer)
        BlendOrchestrator.shared.setContainer(sharedModelContainer)

        if !PhotoMigration.hasRun {
            let context = ModelContext(sharedModelContainer)
            PhotoMigration.run(in: context, fileBytesProvider: { path in
                // Best-effort read: returns nil if file is missing.
                guard let url = AudioRecordingManager.shared.getRecordingURL(fileName: path) else { return nil }
                return try? Data(contentsOf: url)
            })
        }
    }

    var body: some Scene {
        WindowGroup {
            SimpleMainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
