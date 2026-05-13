//
//  FakeBlendAdapter.swift
//  MuesliTests
//
//  In-memory blend adapter for tests. Records calls and returns canned
//  BlendResponse / PhotoResponse data.
//

import Foundation
@testable import Muesli

actor FakeBlendAdapter: BlendPort {
    var stubSessionId = UUID()
    var stubPhotoResponse = PhotoResponse(photoId: "fake", ocrText: "", description: "")
    var stubBlendResponse = BlendResponse(
        blendedMarkdown: "Fake blend",
        userNoteSpans: [],
        quoteSpans: [],
        imagePlacements: [],
        citations: [],
        chapters: [],
        costMicros: 0
    )

    private(set) var createSessionCount = 0
    private(set) var uploadAudioCount = 0
    private(set) var uploadPhotoCount = 0
    private(set) var runBlendCount = 0

    func createSession() async throws -> UUID {
        createSessionCount += 1
        return stubSessionId
    }

    func uploadAudio(sessionId: UUID, audioURL: URL, durationSeconds: Double) async throws {
        uploadAudioCount += 1
    }

    func uploadPhoto(sessionId: UUID, photo: Photo, jpegData: Data) async throws -> PhotoResponse {
        uploadPhotoCount += 1
        return stubPhotoResponse
    }

    func runBlend(sessionId: UUID, userNotes: String) async throws -> BlendResponse {
        runBlendCount += 1
        return stubBlendResponse
    }
}
