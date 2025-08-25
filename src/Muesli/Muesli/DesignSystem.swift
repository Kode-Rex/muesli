//
//  DesignSystem.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.white
        static let secondary = Color.gray
        static let accent = Color.teal
        static let background = Color.black
        static let cardBackground = Color.gray.opacity(0.15)
        static let divider = Color.gray.opacity(0.3)
        static let searchBackground = Color.gray.opacity(0.2)
        static let archiveAccent = Color.orange
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.bold)
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let bodyRegular = Font.system(size: 16)
        static let captionRegular = Font.system(size: 14)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 25
    }
    
    // MARK: - Icon Sizes
    struct IconSize {
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        static let xxl: CGFloat = 60
    }
}

// MARK: - Reusable Components
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.secondary)
            .padding(.horizontal, DesignSystem.Spacing.xl)
    }
}

// MARK: - View Modifiers
extension View {
    func muesliCard() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    func muesliSection() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.lg)
    }
}
