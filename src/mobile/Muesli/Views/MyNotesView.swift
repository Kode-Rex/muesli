//
//  MyNotesView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct MyNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Note
    @State private var editedNotes: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit your personal notes:")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    TextEditor(text: $editedNotes)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        .onChange(of: editedNotes) { _, newValue in
                            saveNotes(newValue)
                        }

                    Spacer()
                }
            }
            .navigationTitle("My Notes")
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
            editedNotes = note.userNotes
        }
    }

    private func saveNotes(_ newNotes: String) {
        note.userNotes = newNotes
        // Regenerate summary with updated user notes
        note.aiSummary = SimpleSummaryGenerator.generateSummary(from: note.content, userNotes: newNotes)
        do {
            try modelContext.save()
        } catch {
            AppLogger.shared.error("Failed to save user notes", error: error)
        }
    }
}