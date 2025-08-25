//
//  NoteDetailView_New.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import UIKit

struct NoteDetailView_New: View {
    // MARK: - Properties
    let note: NoteDisplayModel
    
    // MARK: - State
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NoteDetailViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    NoteHeaderView(note: note)
                    Divider().background(DesignSystem.Colors.divider)
                    ContentRenderer(content: note.content)
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NoteActionsButton(note: note, viewModel: viewModel)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingOptionsMenu) {
            ImprovedNoteOptionsView(note: note, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingTranscript) {
            TranscriptView(title: note.title)
        }
        .sheet(isPresented: $viewModel.showingMyNotesOnly) {
            MyNotesView(title: note.title, content: note.content)
        }
        .alert("Edit Title", isPresented: $viewModel.showingEditTitle) {
            TextField("Note title", text: $viewModel.editedTitle)
            Button("Cancel", role: .cancel) { viewModel.editedTitle = "" }
            Button("Save") { /* Save logic */ }
                .disabled(viewModel.editedTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .alert("Edit AI Summary", isPresented: $viewModel.showingAISummaryEdit) {
            Button("Generate New Summary") { /* AI logic */ }
            Button("Edit Existing Summary") { /* Edit logic */ }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to update the AI summary")
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Note Header
private struct NoteHeaderView: View {
    let note: NoteDisplayModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(note.date)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Text(note.title)
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Actions Button
private struct NoteActionsButton: View {
    let note: NoteDisplayModel
    let viewModel: NoteDetailViewModel
    
    var body: some View {
        Button(action: { viewModel.showOptionsMenu() }) {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(DesignSystem.Colors.primary)
                .font(.system(size: DesignSystem.IconSize.md))
        }
    }
}

// MARK: - View Model
class NoteDetailViewModel: ObservableObject {
    @Published var showingOptionsMenu = false
    @Published var showingEditTitle = false
    @Published var showingTranscript = false
    @Published var showingAISummaryEdit = false
    @Published var showingMyNotesOnly = false
    @Published var editedTitle = ""
    
    func showOptionsMenu() {
        showingOptionsMenu = true
    }
    
    func editTitle(currentTitle: String) {
        editedTitle = currentTitle
        showingEditTitle = true
    }
    
    func showTranscript() {
        showingTranscript = true
    }
    
    func showMyNotes() {
        showingMyNotesOnly = true
    }
    
    func copyNotes(content: String) {
        UIPasteboard.general.string = content
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Data Model
struct NoteDisplayModel {
    let title: String
    let content: String
    let date: String
    
    init(title: String, content: String, date: String) {
        self.title = title
        self.content = content
        self.date = date
    }
}



// MARK: - Improved Options View
private struct ImprovedNoteOptionsView: View {
    let note: NoteDisplayModel
    let viewModel: NoteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let options: [NoteAction] = [
        NoteAction(icon: "pencil", title: "Edit title", action: .editTitle),
        NoteAction(icon: "pencil", title: "Edit AI summary", action: .editAISummary),
        NoteAction(icon: "doc.text", title: "View transcript", action: .viewTranscript),
        NoteAction(icon: "square.on.square", title: "Show my notes", action: .showMyNotes),
        NoteAction(icon: "doc.on.doc", title: "Copy notes", action: .copyNotes)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ForEach(options, id: \.title) { option in
                    NoteActionRow(
                        option: option,
                        action: {
                            handleAction(option.action)
                        }
                    )
                    
                    if option != options.last {
                        Divider().background(DesignSystem.Colors.divider)
                    }
                }
                .muesliCard()
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.xl)
                
                Spacer()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleAction(_ action: NoteActionType) {
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch action {
            case .editTitle:
                viewModel.editTitle(currentTitle: note.title)
            case .editAISummary:
                viewModel.showingAISummaryEdit = true
            case .viewTranscript:
                viewModel.showTranscript()
            case .showMyNotes:
                viewModel.showMyNotes()
            case .copyNotes:
                viewModel.copyNotes(content: note.content)
            }
        }
    }
}

// MARK: - Supporting Types
private struct NoteAction: Equatable {
    let icon: String
    let title: String
    let action: NoteActionType
}

private enum NoteActionType {
    case editTitle, editAISummary, viewTranscript, showMyNotes, copyNotes
}

private struct NoteActionRow: View {
    let option: NoteAction
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: option.icon)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: DesignSystem.IconSize.sm))
                    .frame(width: DesignSystem.IconSize.lg)
                
                Text(option.title)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(DesignSystem.Typography.bodyMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(.system(size: DesignSystem.IconSize.sm))
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NoteDetailView_New(
        note: NoteDisplayModel(
            title: "August 2025 HOA Board Meeting",
            content: SampleData.generateContent(for: "August 2025 HOA Board Meeting"),
            date: "Wed 20 Aug"
        )
    )
}
