//
//  NoteOptionsView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import UIKit

struct NoteOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    @Binding var showingEditTitle: Bool
    @Binding var showingAISummaryEdit: Bool
    @Binding var showingTranscript: Bool
    @Binding var showingMyNotesOnly: Bool
    @Binding var editedTitle: String
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Options list
                    VStack(spacing: 0) {
                        NoteOptionRow(
                            icon: "pencil",
                            title: "Edit title",
                            action: {
                                editedTitle = title
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingEditTitle = true
                                }
                            }
                        )
                        
                        Divider().background(DesignSystem.Colors.divider)
                        
                        NoteOptionRow(
                            icon: "pencil",
                            title: "Edit AI summary",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingAISummaryEdit = true
                                }
                            }
                        )
                        
                        Divider().background(DesignSystem.Colors.divider)
                        
                        NoteOptionRow(
                            icon: "doc.text",
                            title: "View transcript",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingTranscript = true
                                }
                            }
                        )
                        
                        Divider().background(DesignSystem.Colors.divider)
                        
                        NoteOptionRow(
                            icon: "square.on.square",
                            title: "Show my notes",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingMyNotesOnly = true
                                }
                            }
                        )
                        
                        Divider().background(DesignSystem.Colors.divider)
                        
                        NoteOptionRow(
                            icon: "doc.on.doc",
                            title: "Copy notes",
                            action: {
                                UIPasteboard.general.string = content
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                dismiss()
                            }
                        )
                    }
                    .muesliCard()
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    Spacer()
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct NoteOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: icon)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: DesignSystem.IconSize.sm))
                    .frame(width: DesignSystem.IconSize.lg, height: DesignSystem.IconSize.lg)
                
                Text(title)
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
