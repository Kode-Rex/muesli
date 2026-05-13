//
//  LiveChatAdapter.swift
//  Muesli
//
//  ChatPort live adapter — talks to /v1/sessions/:id/chat (talk scope) and
//  /v1/chat (multi-session conference scope). Wraps URLSession; the API
//  base URL comes from a constructor parameter so dev/staging routing
//  stays in one place.
//

import Foundation

struct LiveChatAdapter: ChatPort, @unchecked Sendable {
    let baseURL: URL
    let session: URLSession

    /// Resolver mapping a conference UUID to the list of backend session
    /// IDs that belong to it. Tests inject a synchronous closure; the
    /// production composition pre-resolves and passes via the explicit
    /// variant below.
    var sessionIdsResolver: (UUID) async throws -> [UUID]

    init(
        baseURL: URL,
        session: URLSession = .shared,
        sessionIdsResolver: @escaping (UUID) async throws -> [UUID] = { _ in [] }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sessionIdsResolver = sessionIdsResolver
    }

    func send(scope: ChatScope, messages: [ChatTurn]) async throws -> ChatResponse {
        return try await send(scope: scope, messages: messages, sessionIdsResolver: self.sessionIdsResolver)
    }

    /// Explicit-resolver variant used by tests and by ChatViewModel to bypass
    /// the default closure when it already has the session list in hand.
    func send(
        scope: ChatScope,
        messages: [ChatTurn],
        sessionIdsResolver: (UUID) async throws -> [UUID]
    ) async throws -> ChatResponse {
        var request: URLRequest
        let encoder = JSONEncoder()

        switch scope {
        case .talk(let id):
            request = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions/\(id.uuidString)/chat"))
            struct TalkBody: Encodable { let messages: [ChatTurn] }
            request.httpBody = try encoder.encode(TalkBody(messages: messages))
        case .conference(let id):
            let sessionIds = try await sessionIdsResolver(id)
            request = URLRequest(url: baseURL.appendingPathComponent("/v1/chat"))
            struct ConfBody: Encodable { let sessionIds: [UUID]; let messages: [ChatTurn] }
            request.httpBody = try encoder.encode(ConfBody(sessionIds: sessionIds, messages: messages))
        }

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await Self.dataWithRefresh(session: session, request: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatAdapterError.http(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, body: data)
        }
        struct Envelope: Decodable {
            struct Usage: Decodable { let tokensIn: Int; let tokensOut: Int }
            let message: ChatTurn
            let citations: [ChatCitation]
            let usage: Usage
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        return ChatResponse(message: env.message, citations: env.citations)
    }
}

extension LiveChatAdapter {
    /// Authorize + send. On a 401, refresh the access token once and retry.
    fileprivate static func dataWithRefresh(session: URLSession, request: URLRequest) async throws -> (Data, URLResponse) {
        var first = request
        if let token = await TokenStore.shared.accessToken, !token.isEmpty {
            first.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: first)
        guard let http = response as? HTTPURLResponse, http.statusCode == 401 else {
            return (data, response)
        }
        do {
            _ = try await AuthService.shared.refreshAccessToken()
        } catch {
            return (data, response)
        }
        var retry = request
        if let token = await TokenStore.shared.accessToken, !token.isEmpty {
            retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await session.data(for: retry)
    }
}

enum ChatAdapterError: Error, LocalizedError {
    case http(statusCode: Int, body: Data)

    var errorDescription: String? {
        switch self {
        case .http(let code, _): return "Chat request failed (HTTP \(code))."
        }
    }
}
