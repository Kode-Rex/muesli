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
                        },
                        onProcessTranscription: { note in
                            processTranscription(for: note)
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
    
    private func processTranscription(for note: Note) {
        guard note.needsTranscription,
              let audioFilePath = note.audioFilePath,
              let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioFilePath) else {
            AppLogger.shared.warning("Cannot process transcription - invalid audio file")
            return
        }
        
        // Check network connectivity
        guard NetworkMonitor.shared.isConnected else {
            AppLogger.shared.warning("Cannot process transcription - no internet connection")
            return
        }
        
        // Update status to processing
        note.transcriptionStatus = "processing"
        do {
            try modelContext.save()
        } catch {
            AppLogger.shared.dataError("Update Note Status", error: error)
            return
        }
        
        // Process transcription
        Task {
            do {
                let transcript = try await TranscriptionService.shared.transcribeAudioFile(url: audioURL)
                
                DispatchQueue.main.async {
                    note.content = transcript
                    note.transcriptionStatus = "completed"
                    
                    do {
                        try self.modelContext.save()
                        AppLogger.shared.info("Successfully transcribed note: \(note.title)")
                    } catch {
                        AppLogger.shared.dataError("Save Transcription", error: error)
                        note.transcriptionStatus = "failed"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    note.transcriptionStatus = "failed"
                    do {
                        try self.modelContext.save()
                    } catch {
                        AppLogger.shared.dataError("Update Failed Status", error: error)
                    }
                    AppLogger.shared.error("Transcription failed for note: \(note.title)", error: error)
                }
            }
        }
    }
}

// Simple, standard note card
struct SimpleNoteCard: View {
    let note: Note
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onProcessTranscription: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Icon based on audio status
                Image(systemName: note.hasAudio ? "waveform" : "doc.text")
                    .foregroundColor(note.hasAudio ? .orange : .teal)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background((note.hasAudio ? Color.orange : Color.teal).opacity(0.2))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(note.title)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Transcription status indicators
                        if note.hasAudio {
                            if note.isTranscribing {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                    Text("Processing")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            } else if note.needsTranscription {
                                Button(action: {
                                    onProcessTranscription?()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "text.microphone")
                                            .font(.caption)
                                        Text("Transcribe")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if note.transcriptionStatus == "completed" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    HStack {
                        Text(note.timeString)
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        
                        if note.hasAudio && note.duration > 0 {
                            Text("• \(note.durationString)")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
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