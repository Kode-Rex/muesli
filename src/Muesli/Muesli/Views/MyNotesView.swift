//
//  MyNotesView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct MyNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    
    private var personalNotes: [String] {
        SampleData.extractPersonalNotes(from: content)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        if personalNotes.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: "note.text")
                                    .font(.system(size: DesignSystem.IconSize.xxl))
                                    .foregroundColor(DesignSystem.Colors.secondary)
                                
                                Text("No Personal Notes Found")
                                    .font(DesignSystem.Typography.title2)
                                    .foregroundColor(DesignSystem.Colors.secondary)
                                
                                Text("Personal notes and action items will appear here")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        } else {
                            Text("Personal Notes & Action Items")
                                .font(DesignSystem.Typography.title2)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.bottom, DesignSystem.Spacing.sm)
                            
                            ForEach(personalNotes, id: \.self) { note in
                                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                        .font(DesignSystem.Typography.body)
                                        .frame(width: DesignSystem.IconSize.md, height: DesignSystem.IconSize.md)
                                    
                                    Text(note.trimmingCharacters(in: .whitespaces))
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("My Notes")
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
