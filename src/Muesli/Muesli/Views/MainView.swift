//
//  MainView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    
    // MARK: - State
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
    
    // MARK: - Computed Properties
    private var groupedNotes: [(String, [(String, String)])] {
        let activeNotes = sampleNotes.filter { !$0.isArchived }
        let groups = Dictionary(grouping: activeNotes) { $0.date }
        return groups.sorted { $0.key > $1.key }.map { (key, value) in
            (key, value.map { ($0.title, $0.time) })
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeaderView(showingSettings: $showingSettings)
                SearchBarView(searchText: $searchText)
                NotesListView(
                    groupedNotes: groupedNotes,
                    sampleNotes: $sampleNotes,
                    selectedNote: $selectedNote,
                    showingNoteDetail: $showingNoteDetail,
                    showingEditAlert: $showingEditAlert,
                    editingNoteIndex: $editingNoteIndex,
                    editingTitle: $editingTitle
                )
                ChatInputView()
            }
            
            FloatingNewButton(showingNewNote: $showingNewNote)
        }
        .addSheets(
            showingNewNote: $showingNewNote,
            showingSettings: $showingSettings,
            showingArchive: $showingArchive,
            showingNoteDetail: $showingNoteDetail,
            showingEditAlert: $showingEditAlert,
            selectedNote: selectedNote,
            sampleNotes: $sampleNotes,
            editingTitle: $editingTitle,
            editingNoteIndex: $editingNoteIndex
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header View
private struct HeaderView: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        HStack {
            Text("My Notes")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.primary)
            
            Spacer()
            
            Button(action: { showingSettings = true }) {
                Circle()
                    .fill(DesignSystem.Colors.secondary)
                    .frame(width: DesignSystem.IconSize.xl, height: DesignSystem.IconSize.xl)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: DesignSystem.IconSize.md))
                    )
            }
        }
        .muesliSection()
        .padding(.top, DesignSystem.Spacing.sm)
    }
}

// MARK: - Search Bar View
private struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.secondary)
            
            TextField("Search", text: $searchText)
                .foregroundColor(DesignSystem.Colors.primary)
                .font(DesignSystem.Typography.bodyRegular)
        }
        .muesliSection()
        .background(DesignSystem.Colors.searchBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.xl)
    }
}

// MARK: - Notes List View
private struct NotesListView: View {
    let groupedNotes: [(String, [(String, String)])]
    @Binding var sampleNotes: [SampleNote]
    @Binding var selectedNote: (String, String, String)?
    @Binding var showingNoteDetail: Bool
    @Binding var showingEditAlert: Bool
    @Binding var editingNoteIndex: Int?
    @Binding var editingTitle: String
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                ForEach(groupedNotes, id: \.0) { dateGroup in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        SectionHeader(title: dateGroup.0)
                        
                        ForEach(Array(dateGroup.1.enumerated()), id: \.element.0) { index, note in
                            NoteCardView(
                                title: note.0,
                                time: note.1,
                                icon: "doc.text"
                            )
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .onTapGesture {
                                selectedNote = (note.0, note.1, dateGroup.0)
                                showingNoteDetail = true
                            }
                            .contextMenu {
                                NoteContextMenu(
                                    note: note,
                                    sampleNotes: $sampleNotes,
                                    editingNoteIndex: $editingNoteIndex,
                                    editingTitle: $editingTitle,
                                    showingEditAlert: $showingEditAlert
                                )
                            }
                        }
                    }
                }
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 100)
            }
            .padding(.top, DesignSystem.Spacing.xl)
        }
    }
}

// MARK: - Chat Input View
private struct ChatInputView: View {
    var body: some View {
        HStack {
            Text("Chat with all your meetings")
                .foregroundColor(DesignSystem.Colors.secondary)
                .font(DesignSystem.Typography.bodyRegular)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: DesignSystem.IconSize.sm, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(DesignSystem.Colors.secondary.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .muesliSection()
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Floating New Button
private struct FloatingNewButton: View {
    @Binding var showingNewNote: Bool
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showingNewNote = true }) {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: DesignSystem.IconSize.sm, weight: .semibold))
                        
                        Text("New")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.secondary.opacity(0.8))
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                }
                .padding(.trailing, DesignSystem.Spacing.xl)
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Context Menu
private struct NoteContextMenu: View {
    let note: (String, String)
    @Binding var sampleNotes: [SampleNote]
    @Binding var editingNoteIndex: Int?
    @Binding var editingTitle: String
    @Binding var showingEditAlert: Bool
    
    var body: some View {
        Button(action: {
            if let originalIndex = sampleNotes.firstIndex(where: { $0.title == note.0 && $0.time == note.1 }) {
                editingNoteIndex = originalIndex
                editingTitle = note.0
                showingEditAlert = true
            }
        }) {
            Label("Edit Title", systemImage: "pencil")
        }
        
        Button(action: {
            if let originalIndex = sampleNotes.firstIndex(where: { $0.title == note.0 && $0.time == note.1 }) {
                sampleNotes[originalIndex] = (note.0, note.1, sampleNotes[originalIndex].date, true)
            }
        }) {
            Label("Archive", systemImage: "archivebox")
        }
    }
}

// MARK: - View Extension for Sheets
private extension View {
    func addSheets(
        showingNewNote: Binding<Bool>,
        showingSettings: Binding<Bool>,
        showingArchive: Binding<Bool>,
        showingNoteDetail: Binding<Bool>,
        showingEditAlert: Binding<Bool>,
        selectedNote: (String, String, String)?,
        sampleNotes: Binding<[SampleNote]>,
        editingTitle: Binding<String>,
        editingNoteIndex: Binding<Int?>
    ) -> some View {
        self
            .sheet(isPresented: showingNewNote) {
                NewNoteView()
            }
            .sheet(isPresented: showingSettings) {
                SettingsView(sampleNotes: sampleNotes, showingArchive: showingArchive)
            }
            .sheet(isPresented: showingArchive) {
                ArchiveView(sampleNotes: sampleNotes)
            }
            .sheet(isPresented: showingNoteDetail) {
                if let note = selectedNote {
                    NoteDetailView(
                        title: note.0,
                        content: SampleData.generateContent(for: note.0),
                        date: note.2
                    )
                }
            }
            .alert("Edit Title", isPresented: showingEditAlert) {
                TextField("Note title", text: editingTitle)
                
                Button("Cancel", role: .cancel) {
                    editingNoteIndex.wrappedValue = nil
                    editingTitle.wrappedValue = ""
                }
                
                Button("Save") {
                    if let index = editingNoteIndex.wrappedValue {
                        sampleNotes.wrappedValue[index] = (
                            editingTitle.wrappedValue,
                            sampleNotes.wrappedValue[index].time,
                            sampleNotes.wrappedValue[index].date,
                            sampleNotes.wrappedValue[index].isArchived
                        )
                    }
                    editingNoteIndex.wrappedValue = nil
                    editingTitle.wrappedValue = ""
                }
                .disabled(editingTitle.wrappedValue.isEmpty)
            } message: {
                Text("Enter a new title for this note")
            }
    }
}

#Preview {
    MainView()
        .modelContainer(for: Note.self, inMemory: true)
}
