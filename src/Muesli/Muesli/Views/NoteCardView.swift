//
//  NoteCardView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct NoteCardView: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.accent)
                .font(.system(size: DesignSystem.IconSize.md))
                .frame(width: DesignSystem.IconSize.xl, height: DesignSystem.IconSize.xl)
                .background(DesignSystem.Colors.accent.opacity(0.2))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(DesignSystem.Typography.bodyMedium)
                    .lineLimit(1)
                
                Text(time)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(DesignSystem.Typography.captionRegular)
            }
            
            Spacer()
        }
        .muesliSection()
        .muesliCard()
    }
}

struct ArchivedNoteCardView: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            // Archive icon
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.archiveAccent)
                .font(.system(size: DesignSystem.IconSize.md))
                .frame(width: DesignSystem.IconSize.xl, height: DesignSystem.IconSize.xl)
                .background(DesignSystem.Colors.archiveAccent.opacity(0.2))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    .font(DesignSystem.Typography.bodyMedium)
                    .lineLimit(1)
                
                Text(time)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(DesignSystem.Typography.captionRegular)
            }
            
            Spacer()
            
            // Archived indicator
            Text("ARCHIVED")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.archiveAccent)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.archiveAccent.opacity(0.2))
                .cornerRadius(DesignSystem.Spacing.xs)
        }
        .muesliSection()
        .background(DesignSystem.Colors.secondary.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

#Preview {
    VStack {
        NoteCardView(
            title: "August 2025 HOA Board Meeting",
            time: "6:20 PM",
            icon: "doc.text"
        )
        
        ArchivedNoteCardView(
            title: "AI integration strategy",
            time: "12:52 PM",
            icon: "archivebox.fill"
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
    .preferredColorScheme(.dark)
}
