//
//  ArchiveView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sampleNotes: [SampleNote]
    @State private var selectedNote: (String, String, String)? = nil
    @State private var showingNoteDetail = false
    
    private var archivedNotes: [(String, String, String)] {
        sampleNotes.filter { $0.isArchived }.map { ($0.title, $0.time, $0.date) }
    }
    
    private var groupedArchivedNotes: [(String, [(String, String)])] {
        let groups = Dictionary(grouping: archivedNotes) { $0.2 }
        return groups.sorted { $0.key > $1.key }.map { (key, value) in
            (key, value.map { ($0.0, $0.1) })
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                if archivedNotes.isEmpty {
                    VStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: DesignSystem.IconSize.xxl))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Text("No Archived Notes")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .padding(.top, DesignSystem.Spacing.lg)
                        
                        Text("Archived notes will appear here")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.secondary.opacity(0.7))
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                            ForEach(groupedArchivedNotes, id: \.0) { dateGroup in
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    SectionHeader(title: dateGroup.0)
                                    
                                    ForEach(Array(dateGroup.1.enumerated()), id: \.element.0) { index, note in
                                        ArchivedNoteCardView(
                                            title: note.0,
                                            time: note.1,
                                            icon: "archivebox.fill"
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.xl)
                                        .onTapGesture {
                                            selectedNote = (note.0, note.1, archivedNotes.first { $0.0 == note.0 && $0.1 == note.1 }?.2 ?? "")
                                            showingNoteDetail = true
                                        }
                                        .contextMenu {
                                            Button(action: {
                                                if let originalIndex = sampleNotes.firstIndex(where: { $0.title == note.0 && $0.time == note.1 && $0.isArchived == true }) {
                                                    sampleNotes[originalIndex] = (note.0, note.1, sampleNotes[originalIndex].date, false)
                                                }
                                            }) {
                                                Label("Unarchive", systemImage: "arrow.up.bin")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                if let originalIndex = sampleNotes.firstIndex(where: { $0.title == note.0 && $0.time == note.1 && $0.isArchived == true }) {
                                                    sampleNotes.remove(at: originalIndex)
                                                }
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                NoteDetailView(title: note.0, content: SampleData.generateContent(for: note.0), date: note.2)
            }
        }
        .preferredColorScheme(.dark)
    }
}
