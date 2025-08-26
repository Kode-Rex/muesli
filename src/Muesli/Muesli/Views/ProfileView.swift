//
//  ProfileView.swift
//  Muesli
//
//  User profile management view
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userDisplayName") private var displayName = ""
    @AppStorage("userEmail") private var email = ""
    @AppStorage("userOrganization") private var organization = ""
    @AppStorage("defaultSessionType") private var defaultSessionType = "note"
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("autoArchiveOldNotes") private var autoArchiveOldNotes = false
    
    private let sessionTypes = ["note", "meeting", "session"]
    
    var body: some View {
        NavigationView {
            Form {
                // Personal Information Section
                Section("Personal Information") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.teal)
                            .font(.system(size: 50))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "Your Name" : displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(email.isEmpty ? "your.email@example.com" : email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    LabeledContent("Display Name") {
                        TextField("Enter your name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }
                    
                    LabeledContent("Email") {
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .frame(maxWidth: 200)
                    }
                    
                    LabeledContent("Organization") {
                        TextField("Enter organization", text: $organization)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }
                }
                
                // Preferences Section
                Section("Preferences") {
                    Picker("Default Session Type", selection: $defaultSessionType) {
                        ForEach(sessionTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                    
                    Toggle("Auto-archive old notes", isOn: $autoArchiveOldNotes)
                }
                
                // Statistics Section
                Section("Statistics") {
                    StatisticRow(
                        icon: "doc.text",
                        title: "Total Notes",
                        value: "Loading...",
                        color: .teal
                    )
                    
                    StatisticRow(
                        icon: "archivebox",
                        title: "Archived Notes", 
                        value: "Loading...",
                        color: .orange
                    )
                    
                    StatisticRow(
                        icon: "calendar",
                        title: "Days Active",
                        value: "Loading...",
                        color: .green
                    )
                }
                
                // Actions Section
                Section("Actions") {
                    Button("Export All Notes") {
                        exportAllNotes()
                    }
                    .foregroundColor(.teal)
                    
                    Button("Reset All Settings") {
                        resetSettings()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            AppLogger.shared.userAction("View Profile")
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportAllNotes() {
        // TODO: Implement note export functionality
        AppLogger.shared.userAction("Export All Notes Requested")
        // For now, just log the action
    }
    
    private func resetSettings() {
        displayName = ""
        email = ""
        organization = ""
        defaultSessionType = "note"
        enableNotifications = true
        autoArchiveOldNotes = false
        AppLogger.shared.userAction("Reset Settings")
    }
}

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.gray)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    ProfileView()
}