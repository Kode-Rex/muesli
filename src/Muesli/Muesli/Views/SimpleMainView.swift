//
//  SimpleMainView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

struct SimpleMainView: View {
    @Environment(\.dataService) private var dataService
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
    
    private var groupedNotes: [(String, [Note])] {
        let groups = Dictionary(grouping: displayedNotes) { note in
            note.dateString
        }
        return groups.sorted { first, second in
            // Sort by date, newest first
            first.value.first?.timestamp ?? Date() > second.value.first?.timestamp ?? Date()
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("My Notes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .onChange(of: searchText) { _, newValue in
                                handleSearchTextChange(newValue)
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Notes list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedNotes, id: \.0) { dateGroup in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(dateGroup.0)
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(dateGroup.1) { note in
                                        SimpleNoteCard(
                                            title: note.title,
                                            time: note.timeString,
                                            onTap: {
                                                selectedNote = note
                                                showingNoteDetail = true
                                            },
                                            onEdit: {
                                                editingNote = note
                                                editingTitle = note.title
                                                showingEditAlert = true
                                            },
                                            onArchive: {
                                                archiveNote(note)
                                            }
                                        )
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                            
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 100)
                        }
                        .padding(.top, 20)
                    }
                    
                    // Chat input
                    HStack {
                        Text("Chat with all your meetings")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // Floating button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingNewNote = true }) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("New")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(25)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
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
    }
    
    // MARK: - Helper Methods
    
    private func handleSearchTextChange(_ newValue: String) {
        guard let dataService = dataService else { return }
        
        if newValue.isEmpty {
            isSearching = false
            searchResults = []
        } else {
            isSearching = true
            searchResults = dataService.searchNotes(query: newValue)
        }
    }
    
    private func archiveNote(_ note: Note) {
        guard let dataService = dataService else { return }
        
        do {
            try dataService.archiveNote(note)
        } catch {
            print("Error archiving note: \(error)")
        }
    }
    
    private func saveEditedTitle() {
        guard let dataService = dataService,
              let note = editingNote else { return }
        
        do {
            try dataService.updateNote(note, title: editingTitle)
            editingNote = nil
            editingTitle = ""
        } catch {
            print("Error updating note title: \(error)")
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
        .environment(\.dataService, DataService(modelContext: ModelContext(try! ModelContainer(for: Note.self))))
}
