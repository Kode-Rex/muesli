//
//  NewNoteView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dataService) private var dataService
    @State private var title = ""
    @State private var content = ""
    @State private var conferenceName = ""
    @State private var sessionType = "note"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let sessionTypes = ["note", "meeting", "session"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Title field
                    TextField("Note title", text: $title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Session type and conference name
                    VStack(spacing: 12) {
                        HStack {
                            Text("Type:")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                            
                            Picker("Session Type", selection: $sessionType) {
                                ForEach(sessionTypes, id: \.self) { type in
                                    Text(type.capitalized)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorScheme(.dark)
                        }
                        
                        if sessionType == "meeting" || sessionType == "session" {
                            TextField("Conference/Meeting name (optional)", text: $conferenceName)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Content editor
                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundColor(.teal)
                    .disabled(title.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveNote() {
        guard let dataService = dataService else {
            showError("Data service unavailable")
            return
        }
        
        do {
            let conferenceValue = conferenceName.isEmpty ? nil : conferenceName
            try dataService.createNote(
                title: title,
                content: content,
                conferenceName: conferenceValue,
                sessionType: sessionType
            )
            dismiss()
        } catch {
            showError("Failed to save note: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}