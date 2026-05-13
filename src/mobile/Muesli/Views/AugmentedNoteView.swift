//
//  AugmentedNoteView.swift
//  Muesli
//
//  Flagship note detail view: renders blendedMarkdown + parallel char-range
//  overlays + photo cards as a vertically-scrolling document.
//

import SwiftUI

struct AugmentedNoteView: View {
    let note: Note

    private var segments: [BlendSegment] {
        BlendRenderer.render(note: note)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if segments.isEmpty {
                    blendStatusFallback
                } else {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        switch seg {
                        case .text(let attr):
                            Text(attr)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        case .photo(let photo, let caption):
                            SlideCard(photo: photo, caption: caption)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let conf = note.resolvedConferenceName {
                    Text(conf)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                if let speaker = note.speaker {
                    Text("· \(speaker)").font(.caption).foregroundColor(.secondary)
                }
                Text("· \(note.dateString)").font(.caption).foregroundColor(.secondary)
            }
            Text(note.title)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var blendStatusFallback: some View {
        switch note.blendStatus {
        case .idle, .transcribing, .transcribed, .extracting, .blending:
            VStack(spacing: 8) {
                ProgressView()
                Text("Preparing note…").font(.footnote).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        case .failed:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                Text(note.blendError ?? "Blend failed.").font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        case .complete:
            Text(note.transcript ?? note.content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
