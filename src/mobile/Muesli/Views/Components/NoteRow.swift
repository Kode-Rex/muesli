//
//  NoteRow.swift
//  Muesli
//
//  Notes-list row: title + (conference · speaker · relative date · slide count).
//

import SwiftUI

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            HStack(spacing: 4) {
                if let conf = note.resolvedConferenceName {
                    Text(conf).font(.caption.weight(.semibold)).foregroundColor(.accentColor)
                    dot
                }
                if let speaker = note.speaker {
                    Text(speaker).font(.caption).foregroundColor(.secondary)
                    dot
                }
                Text(relativeDate(note.timestamp)).font(.caption).foregroundColor(.secondary)
                if !note.photos.isEmpty {
                    dot
                    Text("\(note.photos.count) slides").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dot: some View {
        Text("·").font(.caption).foregroundColor(.secondary)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
