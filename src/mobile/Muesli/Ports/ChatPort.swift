//
//  ChatPort.swift
//  Muesli
//
//  Port (interface) for chat. Live adapter will be added in Phase 6
//  (chat backend); for now the live composition uses an unavailable
//  placeholder that throws ChatPortError.notImplemented.
//

import Foundation

struct ChatTurn: Codable, Sendable, Equatable {
    let role: String   // "user" | "assistant"
    let content: String
}

enum ChatCitationKind: String, Codable, Sendable {
    case transcript, note
}

struct ChatCitation: Codable, Sendable, Equatable {
    let kind: ChatCitationKind
    let talkId: UUID?
    let noteId: UUID?
    let startSec: Double?
    let endSec: Double?
    let label: String?
    let title: String?
}

struct ChatResponse: Codable, Sendable, Equatable {
    let message: ChatTurn
    let citations: [ChatCitation]
}

enum ChatScope {
    case talk(UUID)
    case conference(UUID)
}

enum ChatPortError: Error, LocalizedError {
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .notImplemented: return "Chat is not implemented yet."
        }
    }
}

protocol ChatPort: Sendable {
    func send(scope: ChatScope, messages: [ChatTurn]) async throws -> ChatResponse
}

/// Live placeholder until Phase 6 lands the chat backend + iOS adapter.
struct UnimplementedChatAdapter: ChatPort {
    func send(scope: ChatScope, messages: [ChatTurn]) async throws -> ChatResponse {
        throw ChatPortError.notImplemented
    }
}
