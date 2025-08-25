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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SimpleMainView()
                .onAppear {
                    addSampleNotesIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func addSampleNotesIfNeeded() {
        // Add sample notes if database is empty
        let context = sharedModelContainer.mainContext
        
        let descriptor = FetchDescriptor<Note>()
        do {
            let existingNotes = try context.fetch(descriptor)
            if existingNotes.isEmpty {
                // Add sample notes
                let sampleNotes = [
                    Note(title: "Meeting Notes", content: "Today's discussion covered important project updates.", timestamp: Date(), conferenceName: nil, sessionType: "note", isArchived: false),
                    Note(title: "Project Planning", content: "Need to finalize timeline and deliverables.", timestamp: Date().addingTimeInterval(-3600), conferenceName: nil, sessionType: "note", isArchived: false),
                    Note(title: "Ideas", content: "Some creative ideas for the next sprint.", timestamp: Date().addingTimeInterval(-7200), conferenceName: nil, sessionType: "note", isArchived: false)
                ]
                
                for note in sampleNotes {
                    context.insert(note)
                }
                
                try context.save()
                AppLogger.shared.dataSuccess("Sample Data Seeding", details: "Added \(sampleNotes.count) sample notes")
            }
        } catch {
            AppLogger.shared.dataError("Sample Data Seeding", error: error)
        }
    }
}
