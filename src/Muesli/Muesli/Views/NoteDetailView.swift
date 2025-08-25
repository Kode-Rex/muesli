//
//  NoteDetailView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    let date: String
    @State private var showingEditTitle = false
    @State private var editedTitle = ""
    @State private var showingTranscript = false
    @State private var showingAISummaryEdit = false
    @State private var showingOptionsMenu = false
    @State private var showingMyNotesOnly = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                        // Header with date
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(date)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text(title)
                                .font(DesignSystem.Typography.title2)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .background(DesignSystem.Colors.divider)
                        
                        // Content
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            ForEach(SampleData.parseContent(content), id: \.0) { item in
                                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                    if item.1 == .header {
                                        Text(item.0)
                                            .font(DesignSystem.Typography.title3)
                                            .foregroundColor(DesignSystem.Colors.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(item.1 == .bullet ? "•" : "○")
                                            .foregroundColor(item.1 == .bullet ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary)
                                            .font(DesignSystem.Typography.body)
                                            .frame(width: 12, alignment: .leading)
                                        
                                        Text(item.0)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.leading, item.1 == .subBullet ? DesignSystem.Spacing.xl : 0)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingOptionsMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: DesignSystem.IconSize.md))
                    }
                }
            }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: title)
        }
        .sheet(isPresented: $showingOptionsMenu) {
            NoteOptionsView(
                title: title,
                content: content,
                showingEditTitle: $showingEditTitle,
                showingAISummaryEdit: $showingAISummaryEdit,
                showingTranscript: $showingTranscript,
                showingMyNotesOnly: $showingMyNotesOnly,
                editedTitle: $editedTitle
            )
        }
        .sheet(isPresented: $showingMyNotesOnly) {
            MyNotesView(title: title, content: content)
        }
        .alert("Edit Title", isPresented: $showingEditTitle) {
            TextField("Note title", text: $editedTitle)
            
            Button("Cancel", role: .cancel) {
                editedTitle = ""
            }
            
            Button("Save") {
                // In a real app, this would update the actual note
                // For now, this is just a UI demonstration
            }
            .disabled(editedTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .alert("Edit AI Summary", isPresented: $showingAISummaryEdit) {
            Button("Generate New Summary") {
                // AI summary generation logic would go here
            }
            
            Button("Edit Existing Summary") {
                // Edit existing summary logic would go here
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to update the AI summary")
        }
        .preferredColorScheme(.dark)
    }
}
