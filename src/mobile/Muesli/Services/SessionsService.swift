//
//  SessionsService.swift
//  Muesli
//
//  Actor-based URLSession client for the /v1/sessions backend API.
//  Covers session creation, audio upload, photo upload, and blend.
//

import Foundation

struct CreateSessionResponse: Decodable { let sessionId: UUID }

struct PhotoResponse: Decodable {
    let photoId: String
    let ocrText: String
    let description: String
}

struct BlendRequest: Encodable {
    let userNotes: String
}

struct UserNoteSpan: Codable { let start: Int; let end: Int }
struct QuoteSpan: Codable {
    let start: Int; let end: Int
    let transcriptStart: Double; let transcriptEnd: Double
    let speaker: String?
}
struct ImagePlacement: Codable { let imageId: String; let charOffset: Int }
struct Citation: Codable {
    let blendStart: Int; let blendEnd: Int
    let transcriptStart: Double; let transcriptEnd: Double
}
struct ChapterDTO: Codable { let start: Double; let title: String; let summary: String? }

struct BlendResponse: Decodable {
    let blendedMarkdown: String
    let userNoteSpans: [UserNoteSpan]
    let quoteSpans: [QuoteSpan]
    let imagePlacements: [ImagePlacement]
    let citations: [Citation]
    let chapters: [ChapterDTO]
    let costMicros: Int
}

actor SessionsService: BlendPort {
    static let shared = SessionsService()
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Anthropic / our backend uses ISO/numeric — no special config needed
        return d
    }()
    private let encoder = JSONEncoder()

    private var baseURL: URL { APIConfig.baseURL }

    /// Apply `Authorization: Bearer …` if TokenStore has a token. Used by
    /// every outbound request so backends with AUTH_ENABLED=true accept them.
    private func authorize(_ req: inout URLRequest) async {
        if let token = await TokenStore.shared.accessToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    func createSession() async throws -> UUID {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions"))
        req.httpMethod = "POST"
        await authorize(&req)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(CreateSessionResponse.self, from: data).sessionId
    }

    func uploadAudio(sessionId: UUID, audioURL: URL, durationSeconds: Double) async throws {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/audio")
        let (data, name, mime) = (try Data(contentsOf: audioURL), audioURL.lastPathComponent, "audio/mp4")
        try await uploadMultipart(url: url, fields: ["durationSeconds": String(durationSeconds)], file: (name: "audio", filename: name, mime: mime, data: data))
    }

    func uploadPhoto(sessionId: UUID, upload: PhotoUpload) async throws -> PhotoResponse {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/photos")
        let body = try await uploadMultipart(
            url: url,
            fields: [
                "photoId": upload.photoId.uuidString,
                "capturedAt": String(Int(upload.capturedAt.timeIntervalSince1970 * 1_000))
            ],
            file: (name: "photo", filename: "\(upload.contentHash).jpg", mime: "image/jpeg", data: upload.jpegData)
        )
        return try decoder.decode(PhotoResponse.self, from: body)
    }

    func runBlend(sessionId: UUID, userNotes: String) async throws -> BlendResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/blend"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(BlendRequest(userNotes: userNotes))
        await authorize(&req)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(BlendResponse.self, from: data)
    }

    @discardableResult
    private func uploadMultipart(url: URL, fields: [String: String], file: (name: String, filename: String, mime: String, data: Data)) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        await authorize(&req)

        var body = Data()
        for (k, v) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(file.mime)\r\n\r\n".data(using: .utf8)!)
        body.append(file.data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, _) = try await session.data(for: req)
        return data
    }
}
