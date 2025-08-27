//
//  DeveloperStatusView.swift  
//  Muesli
//
//  Read-only view showing current API configuration (development only)
//

import SwiftUI

#if DEBUG
struct DeveloperStatusView: View {
    @State private var transcriptionService = TranscriptionService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Label("Environment", systemImage: "server.rack")
                        Spacer()
                        Text(transcriptionService.environmentName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Endpoint", systemImage: "link")
                        Spacer()
                        Text(transcriptionService.isUsingLocalhost ? "Localhost" : "Remote")
                            .foregroundColor(transcriptionService.isUsingLocalhost ? .orange : .green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(transcriptionService.currentAPIEndpoint)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Configuration is determined at build time. Localhost is checked automatically in development builds.")
                }
            }
            .navigationTitle("API Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DeveloperStatusView()
}
#endif