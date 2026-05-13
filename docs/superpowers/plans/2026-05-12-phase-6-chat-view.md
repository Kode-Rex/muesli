# Phase 6: ChatView (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development.

**Goal:** iOS `ChatView` modal sheet that talks to the chat backend shipped in Phase 2. Scope chip switches between talk (single note) and conference (multiple notes). Threads persisted to SwiftData (`ChatThread` + `ChatMessage`). Citation chips render mm:ss for transcript citations and the note title for note citations. Both `ConferenceDetailView` and `AugmentedNoteView` gain a chat entry point.

**Architecture:**
- `LiveChatAdapter` — `ChatPort` conforming live adapter built on `URLSession`. Replaces the `UnimplementedChatAdapter` in `World.live`.
- `ChatScope` (already in `ChatPort.swift`) carries the `talk(noteId)` / `conference(conferenceId)` discriminator.
- `ChatViewModel` — `@Observable` class that owns the persisted `ChatThread`, the message list, and the in-flight send state. Resolves scope IDs to backend session IDs by reading `note.audioFilePath`-equivalent identifiers (v1 maps `Note.id ⇄ sessionId` 1:1 via the `BlendOrchestrator` flow's session creation; we already round-trip the same UUID).
- `ChatView` — assembled bubbles + scope chip + citation chips + input.

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Scene viii.

**Deviations:**
- The v1 backend takes `sessionIds` in the conference route. The iOS side maps `Note.id` → backend session ID; in this codebase the local Note's ID **is** the backend session ID (`BlendOrchestrator` calls `svc.createSession()` and stores its UUID on `Note`-related state). We pass `note.id.uuidString` straight through as sessionId. If that 1:1 ever breaks, ChatViewModel needs a real ID map — flagged.
- Citation tap → seek in the playback scrubber is implemented for transcript citations (presents `ChapteredPlaybackView(note:startAt:)`). Note citations push that note's `AugmentedNoteView`.

---

## File Structure

**Creating:**
- `src/mobile/Muesli/Adapters/LiveChatAdapter.swift` — production adapter
- `src/mobile/Muesli/ViewModels/ChatViewModel.swift` — `@Observable` thread state
- `src/mobile/Muesli/Views/ChatView.swift`
- `src/mobile/Muesli/Views/Components/CitationChip.swift`
- `src/mobile/MuesliTests/ViewModels/ChatViewModelTests.swift`
- `src/mobile/MuesliTests/Adapters/LiveChatAdapterTests.swift`

**Modifying:**
- `src/mobile/Muesli/World.swift` — replace `UnimplementedChatAdapter` with `LiveChatAdapter` in `.live`
- `src/mobile/Muesli/Views/ConferenceDetailView.swift` — wire the chat button
- `src/mobile/Muesli/Views/AugmentedNoteView.swift` — add a chat button

---

## Task 1: `LiveChatAdapter`

**Files:**
- Create: `src/mobile/Muesli/Adapters/LiveChatAdapter.swift`
- Test: `src/mobile/MuesliTests/Adapters/LiveChatAdapterTests.swift`

- [ ] **Step 1: Failing test — request encoding**

```swift
//
//  LiveChatAdapterTests.swift
//

import Testing
import Foundation
@testable import Muesli

@Suite("Live Chat Adapter Tests", .tags(.unit))
struct LiveChatAdapterTests {

    /// URLProtocol stub that captures the request and returns a canned body.
    final class StubProtocol: URLProtocol {
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var responseBody: Data?
        nonisolated(unsafe) static var status: Int = 200

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            StubProtocol.lastRequest = request
            // Read the request body via httpBodyStream when present.
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1024
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
                var captured = StubProtocol.lastRequest
                captured?.httpBody = data
                StubProtocol.lastRequest = captured
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
        let body = try #require(req.httpBody)
        let decoded = try JSONDecoder().decode([String: [ChatTurn]].self, from: body)
        #expect(decoded["messages"]?.first?.content == "hi")
    }

    @Test("sends conference-scope POST to /v1/chat with sessionIds + messages body")
    func conferenceScopeRequest() async throws {
        let confId = UUID()
        let sessions = [UUID(), UUID()]
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
        let body = try #require(req.httpBody)
        struct Body: Decodable { let sessionIds: [UUID]; let messages: [ChatTurn] }
        let decoded = try JSONDecoder().decode(Body.self, from: body)
        #expect(decoded.sessionIds == sessions)
    }

    @Test("decodes citations correctly")
    func decodesCitations() async throws {
        let talkId = UUID()
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
        // Reset for the next test in the suite.
        StubProtocol.status = 200
    }
}
```

- [ ] **Step 2: Implement `LiveChatAdapter`**

```swift
//
//  LiveChatAdapter.swift
//  Muesli
//
//  ChatPort live adapter — talks to /v1/sessions/:id/chat (talk scope) and
//  /v1/chat (multi-session conference scope). Wraps URLSession; the API
//  base URL comes from APIConfiguration so dev/staging routing stays in
//  one place.
//

import Foundation

struct LiveChatAdapter: ChatPort, @unchecked Sendable {
    let baseURL: URL
    let session: URLSession

    /// Resolver mapping a conference UUID to the list of backend session
    /// IDs that belong to it. The default reaches into the live SwiftData
    /// container; tests inject a synchronous closure.
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

    /// Explicit-resolver variant used by tests to bypass SwiftData.
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

        let (data, response) = try await session.data(for: request)
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

enum ChatAdapterError: Error, LocalizedError {
    case http(statusCode: Int, body: Data)

    var errorDescription: String? {
        switch self {
        case .http(let code, _): return "Chat request failed (HTTP \(code))."
        }
    }
}
```

- [ ] **Step 3: Wire into `World.live`**

In `World.swift`, replace `chat: UnimplementedChatAdapter()` with:

```swift
chat: LiveChatAdapter(
    baseURL: URL(string: "https://staging-api.muesli-app.com/api/v1")!,
    session: .shared,
    sessionIdsResolver: { conferenceId in
        // Resolved at call-time by ChatViewModel from SwiftData; the
        // default returns empty so the World composition doesn't depend
        // on a ModelContainer here. ChatViewModel pre-resolves and
        // injects via the explicit-resolver variant.
        return []
    }
)
```

- [ ] **Step 4: Run tests + build**

- [ ] **Step 5: Commit**

```bash
git add src/mobile/Muesli/Adapters/LiveChatAdapter.swift \
        src/mobile/Muesli/World.swift \
        src/mobile/MuesliTests/Adapters/LiveChatAdapterTests.swift
git commit -m "feat(ios): LiveChatAdapter wires ChatPort to /v1 chat routes

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `ChatViewModel`

**Files:**
- Create: `src/mobile/Muesli/ViewModels/ChatViewModel.swift`
- Test: `src/mobile/MuesliTests/ViewModels/ChatViewModelTests.swift`

- [ ] **Step 1: Failing tests**

```swift
//
//  ChatViewModelTests.swift
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
}
```

- [ ] **Step 2: Implement `ChatViewModel`**

```swift
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
            // Roll back the user message so the thread doesn't show an orphan turn.
            context.delete(userMsg)
            thread.messages.removeAll { $0.id == userMsg.id }
            try? context.save()
            isSending = false
            lastError = error.localizedDescription
            throw error
        }
    }
}
```

- [ ] **Step 3: Run tests, expect PASS, commit**

```bash
git add src/mobile/Muesli/ViewModels/ChatViewModel.swift \
        src/mobile/MuesliTests/ViewModels/ChatViewModelTests.swift
git commit -m "feat(ios): ChatViewModel — append user / call port / append assistant

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `CitationChip` component

**Files:**
- Create: `src/mobile/Muesli/Views/Components/CitationChip.swift`

```swift
//
//  CitationChip.swift
//  Muesli
//
//  Pill-shaped citation reference attached below an assistant message.
//  Transcript citations show mm:ss; note citations show the note title.
//

import SwiftUI

struct CitationChip: View {
    let citation: ChatCitation
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch citation.kind {
        case .transcript: return "clock"
        case .note: return "doc.text"
        }
    }

    private var label: String {
        switch citation.kind {
        case .transcript: return citation.label ?? "Transcript"
        case .note: return citation.title ?? "Note"
        }
    }
}
```

Commit alone.

---

## Task 4: `ChatView`

**Files:**
- Create: `src/mobile/Muesli/Views/ChatView.swift`
- Modify: `src/mobile/Muesli/Views/ConferenceDetailView.swift` — wire button
- Modify: `src/mobile/Muesli/Views/AugmentedNoteView.swift` — add chat button

`ChatView` body in outline:
- Scope chip at top (read from thread.scopeKind / resolves to title via lookup)
- Scrolling list of message bubbles with citation chips below assistants
- Send row with text field + send button (disabled while in-flight)
- `onTap` per citation chip:
  - `.transcript` → presents `ChapteredPlaybackView(note:startAt:)` if the talkId resolves to a local Note
  - `.note` → pushes the noteId's `AugmentedNoteView` (uses `NavigationLink(value:)` if inside a NavigationStack, else dismisses to root and notifies — for v1 we present as a sheet over current navigation)

Wire from:
- `ConferenceDetailView`: replace the disabled button with one that fetches-or-creates a `ChatThread` for this conference and presents `ChatView`. Implementation finds the thread via `FetchDescriptor<ChatThread>(predicate: #Predicate { $0.scopeKindRaw == "conference" && $0.scopeId == conference.id })`; creates a new one if none exists.
- `AugmentedNoteView`: add a toolbar `Ask` button that does the same for `talk(note.id)`.

Commit Task 4 along with the wiring of both call sites.

---

## Phase 6 done when

- Four tasks committed.
- `LiveChatAdapterTests` and `ChatViewModelTests` green.
- Build green.
- Simulator smoke: open conference detail → Chat with this conference → type a question → assistant reply appears with citation chips. Same flow from an AugmentedNote → Ask.

## Next plan

Phase 7: `NewNoteView` polish + `WaveformView` rework.
