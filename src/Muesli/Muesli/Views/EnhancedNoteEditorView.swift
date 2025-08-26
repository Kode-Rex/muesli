//
//  EnhancedNoteEditorView.swift
//  Muesli
//
//  Enhanced note editor with formatting tools
//

import SwiftUI

struct EnhancedNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    @State private var editedContent: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasUnsavedChanges = false
    
    init(note: Note) {
        self.note = note
        self._editedContent = State(initialValue: note.content)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Formatting Toolbar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FormatButton(icon: "textformat", title: "Header") {
                            insertText("# ")
                        }
                        
                        FormatButton(icon: "list.bullet", title: "Bullet") {
                            insertText("• ")
                        }
                        
                        FormatButton(icon: "list.bullet.indent", title: "Sub-bullet") {
                            insertText("○ ")
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        FormatButton(icon: "bold", title: "Bold") {
                            wrapSelection("**", "**")
                        }
                        
                        FormatButton(icon: "italic", title: "Italic") {
                            wrapSelection("*", "*")
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        FormatButton(icon: "checkmark.square", title: "Checklist") {
                            insertText("- [ ] ")
                        }
                        
                        FormatButton(icon: "link", title: "Link") {
                            wrapSelection("[", "](url)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                Divider()
                
                // Content Editor
                TextEditor(text: $editedContent)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding()
                    .onChange(of: editedContent) { _, _ in
                        hasUnsavedChanges = true
                    }
                
                // Word count and status
                HStack {
                    Text("\(wordCount(editedContent)) words")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if hasUnsavedChanges {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("Unsaved changes")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color.black)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Could add confirmation alert here
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.teal)
                    .disabled(!hasUnsavedChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            AppLogger.shared.userAction("Open Enhanced Note Editor", context: note.title)
        }
    }
    
    // MARK: - Helper Methods
    
    private func insertText(_ text: String) {
        editedContent += text
        hasUnsavedChanges = true
        AppLogger.shared.userAction("Insert Format", context: text.trimmingCharacters(in: .whitespaces))
    }
    
    private func wrapSelection(_ prefix: String, _ suffix: String) {
        // For now, just append at the end since TextEditor selection is complex
        editedContent += prefix + "text" + suffix
        hasUnsavedChanges = true
        AppLogger.shared.userAction("Apply Format", context: "\(prefix)...\(suffix)")
    }
    
    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    private func saveChanges() {
        do {
            note.content = editedContent
            try modelContext.save()
            hasUnsavedChanges = false
            AppLogger.shared.userAction("Save Enhanced Note Edit", context: note.title)
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

struct FormatButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.teal)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 60, height: 40)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let sampleNote = Note(
        title: "Sample Note",
        content: "This is some sample content for editing.",
        sessionType: "note"
    )
    
    EnhancedNoteEditorView(note: sampleNote)
}