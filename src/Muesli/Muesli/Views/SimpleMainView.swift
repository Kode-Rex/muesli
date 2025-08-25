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
    
    private var groupedNotes: [(String, [Note])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        
        let groups = Dictionary(grouping: displayedNotes) { note in
            formatter.string(from: note.timestamp)
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
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
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
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(groupedNotes, id: \.0) { dateGroup in
                                // Date header
                                HStack {
                                    Text(dateGroup.0)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 30)
                                .padding(.bottom, 15)
                                
                                // Notes for this date
                                ForEach(dateGroup.1, id: \.id) { note in
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
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    
                    Spacer()
                }
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingNewNote = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.teal)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
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
        .onAppear {
            // Give data more time to load before debug
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                debugNotes()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func debugNotes() {
        print("🔍 SimpleMainView loaded with \(notes.count) notes")
        for (index, note) in notes.enumerated() {
            print("   \(index): '\(note.title)' - content: \(note.content.isEmpty ? "EMPTY" : "\(note.content.count) chars")")
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
            } catch {
                print("Search error: \(error)")
                searchResults = []
            }
        }
    }
    
    private func archiveNote(_ note: Note) {
        do {
            note.isArchived = true
            try modelContext.save()
        } catch {
            print("Error archiving note: \(error)")
        }
    }
    
    private func saveEditedTitle() {
        guard let note = editingNote else { return }
        
        do {
            note.title = editingTitle
            try modelContext.save()
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
}