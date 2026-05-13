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
    @State private var playbackStartAt: Double = 0
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
                            let targets = BlendRenderer.tapTargets(in: attr)
                            if targets.isEmpty {
                                Text(attr)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else {
                                TappableAttributedText(
                                    attributed: attr,
                                    targets: targets
                                ) { seconds in
                                    playbackStartAt = seconds
                                    showingPlayback = true
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                // Chat addresses the backend session by Note.backendSessionId.
                // Before the blend pipeline writes that field the backend has
                // no session row, so 404 would be confusing — gate the button.
                .disabled(note.backendSessionId == nil)
            }
        }
        .sheet(isPresented: $showingPlayback) {
            ChapteredPlaybackView(note: note, startAt: playbackStartAt)
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
            BlendingOverlay(status: note.blendStatus)
        case .failed:
            BlendingOverlay(status: .failed, error: note.blendError)
        case .complete:
            // Inconsistent state: pipeline reported complete but no markdown
            // landed. Surface as an error rather than silently substituting
            // raw transcript, which would hide the corruption.
            BlendingOverlay(
                status: .failed,
                error: "Blend output is missing. Try blending again."
            )
            .onAppear {
                AppLogger.shared.error("AugmentedNoteView: note \(note.id) has blendStatus .complete but blendedMarkdown is nil")
            }
        }
    }
}
