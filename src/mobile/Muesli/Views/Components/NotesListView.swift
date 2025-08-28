//
//  NotesListView.swift
//  Muesli
//
//  Notes list component with grouped sections
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    let notes: [Note]
    let onNoteTap: (Note) -> Void
    let onNoteEdit: (Note) -> Void
    let onNoteArchive: (Note) -> Void
    let onProcessTranscription: ((Note) -> Void)?
    
    private var groupedNotes: [(String, [Note])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        
        let groups = Dictionary(grouping: notes) { note in
            formatter.string(from: note.timestamp)
        }
        
        return groups.sorted { first, second in
            // Sort by date, newest first
            first.value.first?.timestamp ?? Date() > second.value.first?.timestamp ?? Date()
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedNotes, id: \.0) { dateGroup in
                    // Date header
                    DateHeaderView(dateString: dateGroup.0)
                    
                    // Notes for this date
                    ForEach(dateGroup.1, id: \.id) { note in
                        SimpleNoteCard(
                            note: note,
                            onTap: {
                                onNoteTap(note)
                            },
                            onEdit: {
                                onNoteEdit(note)
                            },
                            onArchive: {
                                onNoteArchive(note)
                            },
                            onProcessTranscription: note.needsTranscription ? {
                                onProcessTranscription?(note)
                            } : nil
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }
}

struct DateHeaderView: View {
    let dateString: String
    
    var body: some View {
        HStack {
            Text(dateString)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 15)
    }
}

#Preview {
    let sampleNotes = [
        Note(title: "Sample Note 1", content: "Content 1", timestamp: Date(), sessionType: "note"),
        Note(title: "Sample Note 2", content: "Content 2", timestamp: Date().addingTimeInterval(-3600), sessionType: "note")
    ]
    
    NotesListView(
        notes: sampleNotes,
        onNoteTap: { _ in },
        onNoteEdit: { _ in },
        onNoteArchive: { _ in },
        onProcessTranscription: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}