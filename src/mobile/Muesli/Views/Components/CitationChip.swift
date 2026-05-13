//
//  CitationChip.swift
//  Muesli
//
//  Pill-shaped citation reference attached below an assistant message.
//  Transcript citations show mm:ss; note citations show the note title.
//

import SwiftUI

struct CitationChip: View {
    let citation: ChatCitation
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch citation.kind {
        case .transcript: return "clock"
        case .note: return "doc.text"
        }
    }

    private var label: String {
        switch citation.kind {
        case .transcript: return citation.label ?? "Transcript"
        case .note: return citation.title ?? "Note"
        }
    }
}
