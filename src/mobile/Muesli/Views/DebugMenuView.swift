//
//  DebugMenuView.swift
//  Muesli
//
//  Debug menu for development tools (debug builds only)
//

import SwiftUI
import SwiftData

#if DEBUG
struct DebugMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Sample Data Management") {
                    Button("Reseed Sample Data") {
                        SampleDataManager.reseedDatabase(context: modelContext)
                        showAlert("Sample data refreshed")
                    }
                    
                    Button("Clear All Data") {
                        SampleDataManager.clearAllData(context: modelContext)
                        showAlert("All data cleared")
                    }
                    
                    Button("Add More Sample Notes") {
                        SampleDataManager.seedDatabase(context: modelContext)
                        showAlert("Added more sample notes")
                    }
                }
                
                Section("API Configuration") {
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(APIConfiguration.environmentName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("API URL")
                        Spacer()
                        Text(TranscriptionService.shared.isUsingLocalhost ? "Localhost" : "Remote")
                            .foregroundColor(TranscriptionService.shared.isUsingLocalhost ? .orange : .green)
                    }
                }
                
                Section("Development Info") {
                    HStack {
                        Text("Build Configuration")
                        Spacer()
                        Text("DEBUG")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Current API")
                        Spacer()
                        Text(TranscriptionService.shared.currentAPIEndpoint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Debug Action", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

#Preview {
    DebugMenuView()
}
#endif