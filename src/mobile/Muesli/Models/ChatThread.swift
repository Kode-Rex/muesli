//
//  ChatThread.swift
//  Muesli
//
//  SwiftData entity for a chat conversation, scoped to either a talk or a conference.
//

import Foundation
import SwiftData

enum ChatScopeKind: String, Codable {
    case talk, conference
}

@Model
final class ChatThread {
    var id: UUID
    var scopeKindRaw: String
    var scopeId: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    var messages: [ChatMessage] = []

    var scopeKind: ChatScopeKind {
        get { ChatScopeKind(rawValue: scopeKindRaw) ?? .talk }
        set { scopeKindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scopeKind: ChatScopeKind,
        scopeId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scopeKindRaw = scopeKind.rawValue
        self.scopeId = scopeId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
