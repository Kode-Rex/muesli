//
//  AugmentedNoteView.swift
//  Muesli
//
//  Flagship note detail view: renders blendedMarkdown + parallel char-range
//  overlays + photo cards as a vertically-scrolling document.
//

import SwiftUI
import SwiftData

struct AugmentedNoteView: View {
    let note: Note

    @Environment(\.modelContext) private var modelContext
    @State private var showingPlayback = false
    @State private var chatThread: ChatThread?

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPlayback = true
                } label: {
                    Label("Listen", systemImage: "play.circle")
                }
                .disabled(note.audioFilePath == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openChat()
                } label: {
                    Label("Ask", systemImage: "bubble.left")
                }
            }
        }
        .sheet(isPresented: $showingPlayback) {
            ChapteredPlaybackView(note: note)
        }
        .sheet(item: $chatThread) { thread in
            ChatView(thread: thread, scopeTitle: "Talk · \(note.title)")
        }
    }

    private func openChat() {
        let noteId = note.id
        let talkRaw = ChatScopeKind.talk.rawValue
        let predicate = #Predicate<ChatThread> {
            $0.scopeKindRaw == talkRaw && $0.scopeId == noteId
        }
        if let existing = try? modelContext.fetch(FetchDescriptor<ChatThread>(predicate: predicate)).first {
            chatThread = existing
        } else {
            let thread = ChatThread(scopeKind: .talk, scopeId: note.id)
            modelContext.insert(thread)
            try? modelContext.save()
            chatThread = thread
        }
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
            // Inconsistent state: pipeline reported complete but no markdown
            // landed. Surface as an error rather than silently substituting
            // raw transcript, which would hide the corruption.
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                Text("Blend output is missing. Try blending again.")
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .onAppear {
                AppLogger.shared.error("AugmentedNoteView: note \(note.id) has blendStatus .complete but blendedMarkdown is nil")
            }
        }
    }
}
