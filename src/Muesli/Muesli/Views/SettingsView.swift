//
//  SettingsView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sampleNotes: [SampleNote]
    @Binding var showingArchive: Bool
    
    private var archivedCount: Int {
        sampleNotes.filter { $0.isArchived }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // Profile Section
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        SettingsRow(
                            icon: "person.fill",
                            title: "Profile",
                            showChevron: true,
                            action: {}
                        )
                    }
                    .muesliSection()
                    .muesliCard()
                    
                    // Archive Section
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        SettingsRow(
                            icon: "archivebox.fill",
                            title: "Archive",
                            subtitle: archivedCount > 0 ? "\(archivedCount) archived notes" : nil,
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingArchive = true
                                }
                            }
                        )
                    }
                    .muesliSection()
                    .muesliCard()
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.xxxl)
            }
            .navigationTitle("Settings")
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

struct SettingsRow: View {
    let icon: String
    var iconColor: Color = DesignSystem.Colors.secondary
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: DesignSystem.IconSize.md))
                    .frame(width: DesignSystem.IconSize.lg, height: DesignSystem.IconSize.lg)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .font(DesignSystem.Typography.bodyMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .font(DesignSystem.Typography.captionRegular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .font(.system(size: DesignSystem.IconSize.sm))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
