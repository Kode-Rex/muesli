//
//  ChatViewModelTests.swift
//  MuesliTests
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Chat View Model Tests", .tags(.unit))
struct ChatViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    final class StubChat: ChatPort, @unchecked Sendable {
        var stub: ChatResponse = ChatResponse(
            message: ChatTurn(role: "assistant", content: "ok"),
            citations: []
        )
        private(set) var calls: [(ChatScope, [ChatTurn])] = []
        func send(scope: ChatScope, messages: [ChatTurn]) async throws -> ChatResponse {
            calls.append((scope, messages))
            return stub
        }
    }

    @Test("send persists user + assistant messages to the ChatThread")
    @MainActor
    func sendPersists() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stub = StubChat()
        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        context.insert(thread)
        try context.save()

        let vm = ChatViewModel(thread: thread, chat: stub, context: context)
        try await vm.send(content: "hi")

        let messages = thread.messages.sorted { $0.createdAt < $1.createdAt }
        #expect(messages.count == 2)
        #expect(messages[0].role == .user)
        #expect(messages[0].content == "hi")
        #expect(messages[1].role == .assistant)
        #expect(messages[1].content == "ok")
    }

    @Test("send rolls back the optimistic user message on failure")
    @MainActor
    func sendRollsBackOnFailure() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        struct ThrowingChat: ChatPort, @unchecked Sendable {
            func send(scope: ChatScope, messages: [ChatTurn]) async throws -> ChatResponse {
                throw NSError(domain: "test", code: 1)
            }
        }
        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        context.insert(thread)
        try context.save()
        let vm = ChatViewModel(thread: thread, chat: ThrowingChat(), context: context)
        await #expect(throws: Error.self) {
            try await vm.send(content: "hi")
        }
        #expect(thread.messages.isEmpty)
    }

    @Test("send encodes citations onto the assistant message")
    @MainActor
    func sendCarriesCitations() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stub = StubChat()
        stub.stub = ChatResponse(
            message: ChatTurn(role: "assistant", content: "see"),
            citations: [ChatCitation(kind: .note, talkId: nil, noteId: UUID(), startSec: nil, endSec: nil, label: nil, title: "T")]
        )
        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        context.insert(thread)
        try context.save()
        let vm = ChatViewModel(thread: thread, chat: stub, context: context)
        try await vm.send(content: "?")

        let assistant = thread.messages.first { $0.role == .assistant }
        let citations = (assistant?.citationsJSON).flatMap {
            try? JSONDecoder().decode([ChatCitation].self, from: $0)
        }
        #expect(citations?.count == 1)
        #expect(citations?.first?.kind == .note)
    }

    @Test("send is a no-op for whitespace-only input")
    @MainActor
    func sendNoOpEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stub = StubChat()
        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        context.insert(thread)
        try context.save()
        let vm = ChatViewModel(thread: thread, chat: stub, context: context)
        try await vm.send(content: "   \n\t ")
        #expect(thread.messages.isEmpty)
        #expect(stub.calls.isEmpty)
    }
}
