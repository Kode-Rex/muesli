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
    }

    var body: some Scene {
        WindowGroup {
            SimpleMainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
