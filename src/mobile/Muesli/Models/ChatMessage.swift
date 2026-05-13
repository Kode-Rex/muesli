//
//  ChatMessage.swift
//  Muesli
//
//  SwiftData entity for a single chat message within a ChatThread.
//

import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user, assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var roleRaw: String
    var content: String
    var citationsJSON: Data?
    var createdAt: Date
    var thread: ChatThread?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        citationsJSON: Data? = nil,
        createdAt: Date = Date(),
        thread: ChatThread? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.citationsJSON = citationsJSON
        self.createdAt = createdAt
        self.thread = thread
    }
}
