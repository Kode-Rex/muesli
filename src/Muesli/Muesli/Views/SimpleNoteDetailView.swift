//
//  SimpleNoteDetailView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData
import UIKit

struct SimpleNoteDetailView: View {
    let note: Note
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingOptions = false
    @State private var showingEditTitle = false
    @State private var showingTranscript = false
    @State private var showingMyNotes = false
    @State private var showingAISummaryEditor = false
    @State private var showingEnhancedEditor = false
    @State private var editedTitle = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.dateString)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(note.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Content using simple text parsing
                    NoteContentView(content: note.content)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.black)
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.teal)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingOptions = true }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .popover(isPresented: $showingOptions, attachmentAnchor: .point(.topTrailing), arrowEdge: .top) {
            NoteOptionsPopover(
                note: note,
                onEditTitle: {
                    editedTitle = note.title
                    showingEditTitle = true
                },
                onEditContent: {
                    showingEnhancedEditor = true
                },
                onViewTranscript: {
                    showingTranscript = true
                },
                onShowMyNotes: {
                    showingMyNotes = true
                },
                onEditAISummary: {
                    showingAISummaryEditor = true
                },
                onCopyNotes: {},
                onClose: {
                    showingOptions = false
                }
            )
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: note.title)
        }
        .sheet(isPresented: $showingMyNotes) {
            MyNotesView(title: note.title, content: note.content)
        }
        .sheet(isPresented: $showingAISummaryEditor) {
            AISummaryEditorView(note: note)
        }
        .sheet(isPresented: $showingEnhancedEditor) {
            EnhancedNoteEditorView(note: note)
        }
        .alert("Edit Title", isPresented: $showingEditTitle) {
            TextField("Note title", text: $editedTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") { 
                saveEditedTitle()
            }
            .disabled(editedTitle.isEmpty)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Methods
    
    private func saveEditedTitle() {
        do {
            note.title = editedTitle
            try modelContext.save()
        } catch {
            showError("Failed to update note title: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
}

#Preview {
    let note = Note(
        title: "Sample Meeting Notes",
        content: """
        # Meeting Overview
        
        • Key discussion points covered
        • Action items identified
        • Follow-up meetings scheduled
        
        # Next Steps
        
        ○ Finalize project timeline
        ○ Schedule stakeholder review
        ○ Prepare documentation
        """,
        sessionType: "meeting"
    )
    
    SimpleNoteDetailView(note: note)
        .modelContainer(for: Note.self, inMemory: true)
        .environment(\.dataService, DataService(modelContext: ModelContext(try! ModelContainer(for: Note.self))))
}
