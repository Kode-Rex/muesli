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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataService: DataService?
    
    var body: some View {
        Group {
            if let dataService = dataService {
                SimpleMainView()
                    .environment(\.dataService, dataService)
            } else {
                ProgressView("Loading...")
                    .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            setupDataService()
        }
    }
    
    private func setupDataService() {
        let service = DataService(modelContext: modelContext)
        
        // Seed sample data if needed
        do {
            try service.seedSampleDataIfNeeded()
        } catch {
            print("Error seeding sample data: \(error)")
        }
        
        dataService = service
    }
}
