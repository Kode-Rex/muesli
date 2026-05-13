//
//  LiveChatAdapterTests.swift
//  MuesliTests
//

import Testing
import Foundation
@testable import Muesli

@Suite("Live Chat Adapter Tests", .tags(.unit))
struct LiveChatAdapterTests {
    final class StubProtocol: URLProtocol {
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var lastBody: Data?
        nonisolated(unsafe) static var responseBody: Data?
        nonisolated(unsafe) static var status: Int = 200

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            StubProtocol.lastRequest = request
            // URLSession routes httpBody through httpBodyStream; capture it.
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1_024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer {
                    buffer.deallocate()
                    stream.close()
                }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                StubProtocol.lastBody = data
            } else {
                StubProtocol.lastBody = request.httpBody
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: StubProtocol.status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let body = StubProtocol.responseBody {
                client?.urlProtocol(self, didLoad: body)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }

    @Test("sends talk-scope POST to /v1/sessions/:id/chat with messages body")
    func talkScopeRequest() async throws {
        let noteId = UUID()
        StubProtocol.status = 200
        StubProtocol.responseBody = """
        {"message":{"role":"assistant","content":"Hi"},"citations":[],"usage":{"tokensIn":1,"tokensOut":1}}
        """.data(using: .utf8)
        let adapter = LiveChatAdapter(baseURL: URL(string: "https://api.example.com")!, session: makeSession())
        let resp = try await adapter.send(
            scope: .talk(noteId),
            messages: [ChatTurn(role: "user", content: "hi")]
        )
        #expect(resp.message.content == "Hi")
        let req = try #require(StubProtocol.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/v1/sessions/\(noteId.uuidString)/chat")
        let body = try #require(StubProtocol.lastBody)
        let decoded = try JSONDecoder().decode([String: [ChatTurn]].self, from: body)
        #expect(decoded["messages"]?.first?.content == "hi")
    }

    @Test("sends conference-scope POST to /v1/chat with sessionIds + messages body")
    func conferenceScopeRequest() async throws {
        let confId = UUID()
        let sessions = [UUID(), UUID()]
        StubProtocol.status = 200
        StubProtocol.responseBody = """
        {"message":{"role":"assistant","content":"Hi"},"citations":[],"usage":{"tokensIn":0,"tokensOut":0}}
        """.data(using: .utf8)
        let adapter = LiveChatAdapter(baseURL: URL(string: "https://api.example.com")!, session: makeSession())
        _ = try await adapter.send(
            scope: .conference(confId),
            messages: [ChatTurn(role: "user", content: "hi")],
            sessionIdsResolver: { _ in sessions }
        )
        let req = try #require(StubProtocol.lastRequest)
        #expect(req.url?.path == "/v1/chat")
        let body = try #require(StubProtocol.lastBody)
        struct Body: Decodable { let sessionIds: [UUID]; let messages: [ChatTurn] }
        let decoded = try JSONDecoder().decode(Body.self, from: body)
        #expect(decoded.sessionIds == sessions)
    }

    @Test("decodes citations correctly")
    func decodesCitations() async throws {
        let talkId = UUID()
        StubProtocol.status = 200
        StubProtocol.responseBody = """
        {"message":{"role":"assistant","content":"see"},
         "citations":[
            {"kind":"transcript","talkId":"\(talkId.uuidString)","startSec":12.4,"endSec":24.1,"label":"00:12"},
            {"kind":"note","noteId":"\(talkId.uuidString)","title":"T"}
         ],
         "usage":{"tokensIn":0,"tokensOut":0}}
        """.data(using: .utf8)
        let adapter = LiveChatAdapter(baseURL: URL(string: "https://api.example.com")!, session: makeSession())
        let resp = try await adapter.send(scope: .talk(talkId), messages: [ChatTurn(role: "user", content: "?")])
        #expect(resp.citations.count == 2)
        #expect(resp.citations[0].kind == .transcript)
        #expect(resp.citations[1].kind == .note)
    }

    @Test("throws on non-2xx response")
    func throwsOnError() async throws {
        StubProtocol.status = 502
        StubProtocol.responseBody = #"{"error":"chat_failed"}"#.data(using: .utf8)
        let adapter = LiveChatAdapter(baseURL: URL(string: "https://api.example.com")!, session: makeSession())
        await #expect(throws: Error.self) {
            _ = try await adapter.send(scope: .talk(UUID()), messages: [ChatTurn(role: "user", content: "?")])
        }
        StubProtocol.status = 200
    }
}
