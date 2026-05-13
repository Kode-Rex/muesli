//
//  NoteContentView.swift
//  Muesli
//
//  Note content display component
//

import SwiftUI

struct NoteContentView: View {
    let content: String

    var body: some View {
        ForEach(parseSimpleContent(content), id: \.text) { item in
            SimpleContentItemView(item: item)
        }
    }

    private func parseSimpleContent(_ content: String) -> [SimpleContentData] {
        content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .header)
                } else if trimmed.hasPrefix("• ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .bullet)
                } else if trimmed.hasPrefix("○ ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .subBullet)
                } else {
                    return SimpleContentData(text: trimmed, type: .text)
                }
            }
    }
}

struct SimpleContentItemView: View {
    let item: SimpleContentData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            switch item.type {
            case .header:
                Text(item.text)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .bullet:
                Text("•")
                    .foregroundColor(.white)
                    .frame(width: 12)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .subBullet:
                Text("○")
                    .foregroundColor(.gray)
                    .frame(width: 12)
                    .padding(.leading, 20)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .text:
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SimpleContentData {
    let text: String
    let type: SimpleContentType
}

enum SimpleContentType {
    case header, bullet, subBullet, text
}
