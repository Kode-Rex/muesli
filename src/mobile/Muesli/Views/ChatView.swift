//
//  ChatView.swift
//  Muesli
//
//  Chat sheet for a talk or a conference. Persists messages to SwiftData
//  via ChatViewModel; sends turns through World.current.chat.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let thread: ChatThread
    /// Display title for the scope chip (e.g., "DataSummit 2026 · 12 talks"
    /// or "Talk · The three pillars").
    let scopeTitle: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel?
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopeChip
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel?.messagesSorted ?? []) { message in
                                bubble(for: message)
                                    .id(message.id)
                            }
                            if let err = viewModel?.lastError {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel?.messagesSorted.last?.id) { _, newValue in
                        if let id = newValue {
                            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                }

                inputRow
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(thread: thread, chat: World.current.chat, context: modelContext)
            }
        }
    }

    private var scopeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: thread.scopeKind == .talk ? "doc.text" : "calendar")
                .font(.caption)
            Text(scopeTitle)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
        .foregroundColor(.accentColor)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(for message: ChatMessage) -> some View {
        let isUser = (message.role == .user)
        let citations: [ChatCitation] = (message.citationsJSON).flatMap {
            try? JSONDecoder().decode([ChatCitation].self, from: $0)
        } ?? []
        return HStack {
            if isUser { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.accentColor : Color.gray.opacity(0.15))
                    .foregroundColor(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if !citations.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(citations.enumerated()), id: \.offset) { _, c in
                            CitationChip(citation: c)
                        }
                    }
                }
            }
            if !isUser { Spacer(minLength: 32) }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Ask a question…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await submit() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(viewModel?.isSending ?? false || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func submit() async {
        guard let viewModel else { return }
        let content = draft
        draft = ""
        do {
            try await viewModel.send(content: content)
        } catch {
            // ChatViewModel already records lastError; nothing else to do.
        }
    }
}
