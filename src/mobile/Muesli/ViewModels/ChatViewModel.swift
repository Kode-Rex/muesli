//
//  ChatViewModel.swift
//  Muesli
//
//  Owns one ChatThread's send loop. Appends the user message, calls the
//  ChatPort, then appends the assistant message with citations. Rolls
//  back the user message if the port throws so the thread doesn't show
//  an orphan turn.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    let thread: ChatThread
    let chat: any ChatPort
    let context: ModelContext

    private(set) var isSending = false
    private(set) var lastError: String?

    init(thread: ChatThread, chat: any ChatPort, context: ModelContext) {
        self.thread = thread
        self.chat = chat
        self.context = context
    }

    var messagesSorted: [ChatMessage] {
        thread.messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// For talk-scope chat returns `note.backendSessionId` if available
    /// (falls back to `thread.scopeId` for back-compat / dev seed data).
    /// For conference scope returns the conference's notes' backendSessionIds.
    private func resolveSessionIds() -> [UUID] {
        switch thread.scopeKind {
        case .talk:
            let scopeId = thread.scopeId
            let predicate = #Predicate<Note> { $0.id == scopeId }
            if let note = try? context.fetch(FetchDescriptor<Note>(predicate: predicate)).first {
                if let backend = note.backendSessionId { return [backend] }
            }
            return [scopeId]
        case .conference:
            let scopeId = thread.scopeId
            let predicate = #Predicate<Note> {
                $0.conference?.id == scopeId && !$0.isArchived
            }
            let notes = (try? context.fetch(FetchDescriptor<Note>(predicate: predicate))) ?? []
            return notes.compactMap { $0.backendSessionId }
        }
    }

    func send(content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        lastError = nil

        // Insert; SwiftData's inverse relationship populates thread.messages
        // automatically. Do not manually append to avoid duplicates after the
        // inverse resolves on save.
        let userMsg = ChatMessage(role: .user, content: trimmed, createdAt: Date(), thread: thread)
        context.insert(userMsg)
        try? context.save()

        let resolvedIds = resolveSessionIds()
        let scope: ChatScope
        switch thread.scopeKind {
        case .talk:
            scope = .talk(resolvedIds.first ?? thread.scopeId)
        case .conference:
            scope = .conference(thread.scopeId)
        }

        let history = messagesSorted.map { ChatTurn(role: $0.role.rawValue, content: $0.content) }

        do {
            let response: ChatResponse
            // For conference scope inject the resolved session IDs via the
            // explicit-resolver variant if the port is a LiveChatAdapter.
            if case .conference = scope, let live = chat as? LiveChatAdapter {
                response = try await live.send(
                    scope: scope,
                    messages: history,
                    sessionIdsResolver: { _ in resolvedIds }
                )
            } else {
                response = try await chat.send(scope: scope, messages: history)
            }

            let assistantMsg = ChatMessage(
                role: .assistant,
                content: response.message.content,
                citationsJSON: try? JSONEncoder().encode(response.citations),
                createdAt: Date(),
                thread: thread
            )
            context.insert(assistantMsg)
            thread.updatedAt = Date()
            try? context.save()
            isSending = false
        } catch {
            context.delete(userMsg)
            try? context.save()
            isSending = false
            lastError = error.localizedDescription
            throw error
        }
    }
}
