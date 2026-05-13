//
//  BlendPort.swift
//  Muesli
//
//  Port (interface) for the backend session + blend API. Live adapter
//  is the actor-based SessionsService talking to the Node backend; test
//  fakes return canned BlendResponse objects.
//

import Foundation

protocol BlendPort: Sendable {
    func createSession() async throws -> UUID
    func uploadAudio(sessionId: UUID, audioURL: URL, durationSeconds: Double) async throws
    func uploadPhoto(sessionId: UUID, photo: Photo, jpegData: Data) async throws -> PhotoResponse
    func runBlend(sessionId: UUID, userNotes: String) async throws -> BlendResponse
}
