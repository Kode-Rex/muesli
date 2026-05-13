//
//  BlendPort.swift
//  Muesli
//
//  Port (interface) for the backend session + blend API. Live adapter
//  is the actor-based SessionsService talking to the Node backend; test
//  fakes return canned BlendResponse objects.
//

import Foundation

/// Value-type DTO so callers can hand photo metadata across actor
/// boundaries without dragging the SwiftData `Photo` model with them.
/// Required for Sendable-correct crossings under Swift 6 strict concurrency.
struct PhotoUpload: Sendable {
    let photoId: UUID
    let contentHash: String
    let capturedAt: Date
    let jpegData: Data
}

protocol BlendPort: Sendable {
    func createSession() async throws -> UUID
    func uploadAudio(sessionId: UUID, audioURL: URL, durationSeconds: Double) async throws
    func uploadPhoto(sessionId: UUID, upload: PhotoUpload) async throws -> PhotoResponse
    func runBlend(sessionId: UUID, userNotes: String) async throws -> BlendResponse
}
