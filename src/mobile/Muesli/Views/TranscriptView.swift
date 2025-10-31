//
//  TranscriptView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct TranscriptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Note
    @State private var editedTranscript: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit transcript:")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    TextEditor(text: $editedTranscript)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        .onChange(of: editedTranscript) { _, newValue in
                            saveTranscript(newValue)
                        }

                    Spacer()
                }
            }
            .navigationTitle("Transcript")
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
            editedTranscript = note.content
        }
    }

    private func saveTranscript(_ newTranscript: String) {
        note.content = newTranscript
        // Regenerate summary with updated transcript
        note.aiSummary = SimpleSummaryGenerator.generateSummary(from: newTranscript, userNotes: note.userNotes)
        do {
            try modelContext.save()
        } catch {
            AppLogger.shared.error("Failed to save transcript", error: error)
        }
    }
}