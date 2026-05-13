//
//  AuthService.swift
//  Muesli
//
//  Backend auth surface: dev sign-in (POST /v1/auth/dev), refresh
//  (POST /v1/auth/refresh), and signOut. Tokens are persisted to
//  TokenStore so SessionsService and LiveChatAdapter pick them up.
//

import Foundation

struct AuthUser: Codable, Equatable {
    let id: UUID
    let email: String
    let fullName: String?
}

enum AuthError: Error, LocalizedError {
    case http(status: Int, message: String?)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .http(let status, let msg):
            return msg ?? "Authentication failed (HTTP \(status))."
        case .decodeFailed:
            return "Couldn't read the server response."
        }
    }
}

actor AuthService {
    static let shared = AuthService(
        baseURL: APIConfiguration.baseURL,
        session: .shared,
        store: TokenStore.shared
    )

    private let baseURL: URL
    private let session: URLSession
    private let store: TokenStore

    init(baseURL: URL, session: URLSession, store: TokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.store = store
    }

    /// Dev sign-in. Available only when the backend is in non-production.
    @discardableResult
    func signInDev(email: String, fullName: String? = nil) async throws -> AuthUser {
        struct Body: Encodable { let email: String; let fullName: String? }
        let envelope: AuthEnvelope = try await post(
            path: "/v1/auth/dev",
            body: Body(email: email, fullName: fullName)
        )
        await store.setTokens(access: envelope.accessToken, refresh: envelope.refreshToken)
        return envelope.user
    }

    /// Refresh the access token using the stored refresh token. Returns the
    /// new access token; persists both. Throws if the refresh token is
    /// invalid or revoked.
    @discardableResult
    func refreshAccessToken() async throws -> String {
        guard let refresh = await store.refreshToken else {
            throw AuthError.http(status: 401, message: "No refresh token.")
        }
        struct Body: Encodable { let refreshToken: String }
        struct Resp: Decodable { let accessToken: String; let refreshToken: String }
        let resp: Resp = try await post(path: "/v1/auth/refresh", body: Body(refreshToken: refresh))
        await store.setTokens(access: resp.accessToken, refresh: resp.refreshToken)
        return resp.accessToken
    }

    func signOut() async {
        await store.clear()
    }

    /// Whether the store currently has an access token.
    func isSignedIn() async -> Bool {
        await store.accessToken?.isEmpty == false
    }

    // MARK: - Private

    private struct AuthEnvelope: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: AuthUser
    }

    private func post<B: Encodable, R: Decodable>(path: String, body: B) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw AuthError.http(status: code, message: serverMessage)
        }
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw AuthError.decodeFailed
        }
    }
}
