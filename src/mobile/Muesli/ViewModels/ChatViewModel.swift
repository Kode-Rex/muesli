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

    func send(content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        lastError = nil

        let userMsg = ChatMessage(role: .user, content: trimmed, createdAt: Date(), thread: thread)
        context.insert(userMsg)
        thread.messages.append(userMsg)
        try? context.save()

        let scope: ChatScope = (thread.scopeKind == .talk)
            ? .talk(thread.scopeId)
            : .conference(thread.scopeId)

        let history = messagesSorted.map { ChatTurn(role: $0.role.rawValue, content: $0.content) }

        do {
            let response = try await chat.send(scope: scope, messages: history)
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: response.message.content,
                citationsJSON: try? JSONEncoder().encode(response.citations),
                createdAt: Date(),
                thread: thread
            )
            context.insert(assistantMsg)
            thread.messages.append(assistantMsg)
            thread.updatedAt = Date()
            try? context.save()
            isSending = false
        } catch {
            context.delete(userMsg)
            thread.messages.removeAll { $0.id == userMsg.id }
            try? context.save()
            isSending = false
            lastError = error.localizedDescription
            throw error
        }
    }
}
