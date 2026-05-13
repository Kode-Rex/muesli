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
            HStack(spacing: 6) {
                Text(note.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if isBlending {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Blending in progress")
                }
            }
            HStack(spacing: 4) {
                if let conf = note.resolvedConferenceName {
                    Text(conf).font(.caption.weight(.semibold)).foregroundColor(.accentColor)
                    dot
                }
                if let speaker = note.speaker, !speaker.isEmpty {
                    Text(speaker).font(.caption).foregroundColor(.secondary)
                    dot
                }
                Text(relativeDate(note.timestamp)).font(.caption).foregroundColor(.secondary)
                // Use max of the SwiftData photos count and the legacy
                // imagePaths array — older notes may have only the latter.
                let slideCount = max(note.photos.count, note.imagePaths.count)
                if slideCount > 0 {
                    dot
                    Text("\(slideCount) slides").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var isBlending: Bool {
        switch note.blendStatus {
        case .transcribing, .transcribed, .extracting, .blending: return true
        case .idle, .complete, .failed: return false
        }
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
