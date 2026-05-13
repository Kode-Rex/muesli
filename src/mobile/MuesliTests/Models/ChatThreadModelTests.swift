//
//  ChatThreadModelTests.swift
//  MuesliTests
//
//  Unit tests for the ChatThread and ChatMessage SwiftData entities.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("Chat Thread Model Tests", .tags(.unit))
struct ChatThreadModelTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("ChatThread initializes with talk scope")
    func chatThreadTalkScope() async throws {
        let noteId = UUID()
        let thread = ChatThread(scopeKind: .talk, scopeId: noteId)

        #expect(thread.scopeKind == .talk)
        #expect(thread.scopeId == noteId)
        #expect(thread.messages.isEmpty)
        #expect(thread.createdAt.timeIntervalSinceNow < 1)
        #expect(thread.updatedAt.timeIntervalSinceNow < 1)
    }

    @Test("ChatThread initializes with conference scope")
    func chatThreadConferenceScope() async throws {
        let confId = UUID()
        let thread = ChatThread(scopeKind: .conference, scopeId: confId)

        #expect(thread.scopeKind == .conference)
        #expect(thread.scopeId == confId)
    }

    @Test("ChatMessage initializes with role and content")
    func chatMessageInit() async throws {
        let msg = ChatMessage(role: .user, content: "Hello")

        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.citationsJSON == nil)
        #expect(msg.thread == nil)
    }

    @Test("ChatThread cascade-deletes messages")
    func chatThreadCascadeDeletes() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let thread = ChatThread(scopeKind: .talk, scopeId: UUID())
        let msg1 = ChatMessage(role: .user, content: "Q")
        let msg2 = ChatMessage(role: .assistant, content: "A")
        thread.messages = [msg1, msg2]
        msg1.thread = thread
        msg2.thread = thread

        context.insert(thread)
        context.insert(msg1)
        context.insert(msg2)
        try context.save()

        context.delete(thread)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ChatMessage>())
        #expect(remaining.isEmpty)
    }
}
