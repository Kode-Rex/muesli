//
//  SimpleMainView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

struct SimpleMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isArchived }, sort: \Note.timestamp, order: .reverse) 
    private var notes: [Note]
    
    @State private var searchText = ""
    @State private var showingNewNote = false
    @State private var showingSettings = false
    @State private var showingArchive = false
    @State private var showingNoteDetail = false
    @State private var selectedNote: Note? = nil
    @State private var showingEditAlert = false
    @State private var editingNote: Note?
    @State private var editingTitle = ""
    @State private var searchResults: [Note] = []
    @State private var isSearching = false

    private var displayedNotes: [Note] {
        if isSearching && !searchText.isEmpty {
            return searchResults
        }
        return notes
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    MainHeaderView {
                        showingSettings = true
                    }
                    
                    // Search bar
                    SearchBarView(searchText: $searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
                    
                    // Notes list
                    NotesListView(
                        notes: displayedNotes,
                        onNoteTap: { note in
                            selectedNote = note
                            showingNoteDetail = true
                        },
                        onNoteEdit: { note in
                            editingNote = note
                            editingTitle = note.title
                            showingEditAlert = true
                        },
                        onNoteArchive: { note in
                            archiveNote(note)
                        }
                    )
                    
                    Spacer()
                }
                
                // Floating action button
                FloatingActionButton {
                    showingNewNote = true
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NewNoteView()
        }
        .sheet(isPresented: $showingSettings) {
            SimpleSettingsView(showingArchive: $showingArchive)
        }
        .sheet(isPresented: $showingArchive) {
            SimpleArchiveView()
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                SimpleNoteDetailView(note: note)
            }
        }
        .alert("Edit Title", isPresented: $showingEditAlert) {
            TextField("Note title", text: $editingTitle)
            
            Button("Cancel", role: .cancel) {
                editingNote = nil
                editingTitle = ""
            }
            
            Button("Save") {
                saveEditedTitle()
            }
            .disabled(editingTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Give data more time to load before debug
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                debugNotes()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func debugNotes() {
        AppLogger.shared.viewLifecycle("SimpleMainView", event: .load)
        AppLogger.shared.debug("SimpleMainView loaded with \(notes.count) notes")
        for (index, note) in notes.enumerated() {
            let contentInfo = note.content.isEmpty ? "EMPTY" : "\(note.content.count) chars"
            AppLogger.shared.debug("Note \(index): '\(note.title)' - content: \(contentInfo)")
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            isSearching = false
            searchResults = []
        } else {
            isSearching = true
            // Simple search using SwiftData directly
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate { note in
                    note.title.localizedStandardContains(newValue) && !note.isArchived
                }
            )
            do {
                searchResults = try modelContext.fetch(descriptor)
                AppLogger.shared.searchOperation(query: newValue, resultCount: searchResults.count)
            } catch {
                AppLogger.shared.dataError("Local Search", error: error, details: "Query: '\(newValue)'")
                searchResults = []
            }
        }
    }
    
    private func archiveNote(_ note: Note) {
        do {
            note.isArchived = true
            try modelContext.save()
            AppLogger.shared.noteOperation(.archive, title: note.title)
            AppLogger.shared.userAction("Archive Note", context: note.title)
        } catch {
            AppLogger.shared.dataError("Archive Note", error: error, details: "Title: \(note.title)")
        }
    }
    
    private func saveEditedTitle() {
        guard let note = editingNote else { return }
        
        do {
            let oldTitle = note.title
            note.title = editingTitle
            try modelContext.save()
            AppLogger.shared.noteOperation(.update, title: editingTitle)
            AppLogger.shared.userAction("Edit Title", context: "'\(oldTitle)' → '\(editingTitle)'")
            editingNote = nil
            editingTitle = ""
        } catch {
            AppLogger.shared.dataError("Update Note Title", error: error, details: "Title: \(editingTitle)")
        }
    }
}

// Simple, standard note card
struct SimpleNoteCard: View {
    let title: String
    let time: String
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.teal)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Color.teal.opacity(0.2))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                    
                    Text(time)
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Edit Title", systemImage: "pencil", action: onEdit)
            Button("Archive", systemImage: "archivebox", action: onArchive)
        }
    }
}

#Preview {
    SimpleMainView()
        .modelContainer(for: Note.self, inMemory: true)
}