//
//  SimpleArchiveView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

struct SimpleArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isArchived }, sort: \Note.timestamp, order: .reverse) 
    private var archivedNotes: [Note]
    
    @State private var selectedNote: Note? = nil
    @State private var showingNoteDetail = false
    
    private var groupedArchivedNotes: [(String, [Note])] {
        let groups = Dictionary(grouping: archivedNotes) { note in
            note.dateString
        }
        return groups.sorted { first, second in
            // Sort by date, newest first
            first.value.first?.timestamp ?? Date() > second.value.first?.timestamp ?? Date()
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if archivedNotes.isEmpty {
                    VStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Archived Notes")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        
                        Text("Archived notes will appear here")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedArchivedNotes, id: \.0) { dateGroup in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(dateGroup.0)
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(dateGroup.1) { note in
                                        SimpleArchivedNoteCard(
                                            title: note.title,
                                            time: note.timeString,
                                            onTap: {
                                                selectedNote = note
                                                showingNoteDetail = true
                                            },
                                            onUnarchive: {
                                                unarchiveNote(note)
                                            },
                                            onDelete: {
                                                deleteNote(note)
                                            }
                                        )
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                SimpleNoteDetailView(note: note)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Methods
    
    private func unarchiveNote(_ note: Note) {
        do {
            note.isArchived = false
            try modelContext.save()
        } catch {
            AppLogger.shared.dataError("Unarchive Note", error: error, details: "Title: \(note.title)")
        }
    }
    
    private func deleteNote(_ note: Note) {
        do {
            modelContext.delete(note)
            try modelContext.save()
        } catch {
            AppLogger.shared.dataError("Delete Note", error: error, details: "Title: \(note.title)")
        }
    }
}

struct SimpleArchivedNoteCard: View {
    let title: String
    let time: String
    let onTap: () -> Void
    let onUnarchive: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                    
                    Text(time)
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                
                Spacer()
                
                Text("ARCHIVED")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Unarchive", systemImage: "arrow.up.bin", action: onUnarchive)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

#Preview {
    SimpleArchiveView()
        .modelContainer(for: Note.self, inMemory: true)
}
