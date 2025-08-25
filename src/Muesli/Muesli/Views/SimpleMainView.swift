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
    @Query private var notes: [Note]
    
    @State private var searchText = ""
    @State private var showingNewNote = false
    @State private var showingSettings = false
    @State private var showingArchive = false
    @State private var showingNoteDetail = false
    @State private var selectedNote: (String, String, String)? = nil
    @State private var showingEditAlert = false
    @State private var editingNoteIndex: Int?
    @State private var editingTitle = ""
    @State private var sampleNotes = SampleData.notes
    
    private var activeNotes: [SampleNote] {
        sampleNotes.filter { !$0.isArchived }
    }
    
    private var groupedNotes: [(String, [SampleNote])] {
        let groups = Dictionary(grouping: activeNotes) { $0.date }
        return groups.sorted { $0.key > $1.key }.map { (key, value) in
            (key, value)
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
                                    
                                    ForEach(dateGroup.1, id: \.title) { note in
                                        SimpleNoteCard(
                                            title: note.title,
                                            time: note.time,
                                            onTap: {
                                                selectedNote = (note.title, note.time, note.date)
                                                showingNoteDetail = true
                                            },
                                            onEdit: {
                                                if let index = sampleNotes.firstIndex(where: { $0.title == note.title }) {
                                                    editingNoteIndex = index
                                                    editingTitle = note.title
                                                    showingEditAlert = true
                                                }
                                            },
                                            onArchive: {
                                                if let index = sampleNotes.firstIndex(where: { $0.title == note.title }) {
                                                    sampleNotes[index] = (note.title, note.time, note.date, true)
                                                }
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
            SimpleSettingsView(sampleNotes: $sampleNotes, showingArchive: $showingArchive)
        }
        .sheet(isPresented: $showingArchive) {
            SimpleArchiveView(sampleNotes: $sampleNotes)
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                SimpleNoteDetailView(
                    title: note.0,
                    content: SampleData.generateContent(for: note.0),
                    date: note.2
                )
            }
        }
        .alert("Edit Title", isPresented: $showingEditAlert) {
            TextField("Note title", text: $editingTitle)
            
            Button("Cancel", role: .cancel) {
                editingNoteIndex = nil
                editingTitle = ""
            }
            
            Button("Save") {
                if let index = editingNoteIndex {
                    sampleNotes[index] = (editingTitle, sampleNotes[index].time, sampleNotes[index].date, sampleNotes[index].isArchived)
                }
                editingNoteIndex = nil
                editingTitle = ""
            }
            .disabled(editingTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .preferredColorScheme(.dark)
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
