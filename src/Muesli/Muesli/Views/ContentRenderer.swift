//
//  ContentRenderer.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct ContentRenderer: View {
    let content: String
    
    private var parsedContent: [(String, ContentType)] {
        SampleData.parseContent(content)
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(parsedContent.enumerated()), id: \.offset) { index, item in
                ContentItemView(text: item.0, type: item.1)
            }
        }
    }
}

private struct ContentItemView: View {
    let text: String
    let type: ContentType
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            switch type {
            case .header:
                Text(text)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
            case .bullet:
                BulletPointView(text: text, bullet: "•", color: DesignSystem.Colors.primary)
                
            case .subBullet:
                BulletPointView(text: text, bullet: "○", color: DesignSystem.Colors.secondary)
                    .padding(.leading, DesignSystem.Spacing.xl)
            }
        }
    }
}

private struct BulletPointView: View {
    let text: String
    let bullet: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Text(bullet)
                .foregroundColor(color)
                .font(DesignSystem.Typography.body)
                .frame(width: 12, alignment: .leading)
            
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ContentRenderer(content: SampleData.generateContent(for: "August 2025 HOA Board Meeting"))
        .padding()
        .background(DesignSystem.Colors.background)
        .preferredColorScheme(.dark)
}
