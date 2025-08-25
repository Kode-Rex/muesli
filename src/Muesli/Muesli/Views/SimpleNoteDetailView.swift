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
    @Environment(\.dataService) private var dataService
    @State private var showingOptions = false
    @State private var showingEditTitle = false
    @State private var showingTranscript = false
    @State private var showingMyNotes = false
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
                    ForEach(parseSimpleContent(note.content), id: \.text) { item in
                        SimpleContentItemView(item: item)
                    }
                    
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
            VStack(spacing: 0) {
                NoteOptionRow(
                    icon: "pencil",
                    title: "Edit title"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editedTitle = note.title
                        showingEditTitle = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "pencil",
                    title: "Edit AI summary"
                ) {
                    showingOptions = false
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "doc.text",
                    title: "View transcript"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingTranscript = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "square.on.square",
                    title: "Show my notes"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingMyNotes = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "doc.on.doc",
                    title: "Copy notes"
                ) {
                    UIPasteboard.general.string = note.content
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showingOptions = false
                }
            }
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .cornerRadius(12)
            .frame(width: 200)
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: note.title)
        }
        .sheet(isPresented: $showingMyNotes) {
            MyNotesView(title: note.title, content: note.content)
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
        guard let dataService = dataService else {
            showError("Data service unavailable")
            return
        }
        
        do {
            try dataService.updateNote(note, title: editedTitle)
        } catch {
            showError("Failed to update note title: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func parseSimpleContent(_ content: String) -> [SimpleContentData] {
        content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .header)
                } else if trimmed.hasPrefix("• ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .bullet)
                } else if trimmed.hasPrefix("○ ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .subBullet)
                } else {
                    return SimpleContentData(text: trimmed, type: .text)
                }
            }
    }
}

struct SimpleContentItemView: View {
    let item: SimpleContentData
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            switch item.type {
            case .header:
                Text(item.text)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .bullet:
                Text("•")
                    .foregroundColor(.white)
                    .frame(width: 12)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .subBullet:
                Text("○")
                    .foregroundColor(.gray)
                    .frame(width: 12)
                    .padding(.leading, 20)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .text:
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SimpleContentData {
    let text: String
    let type: SimpleContentType
}

enum SimpleContentType {
    case header, bullet, subBullet, text
}


// MARK: - Note Option Row
private struct NoteOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
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
