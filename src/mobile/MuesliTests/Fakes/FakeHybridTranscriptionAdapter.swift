//
//  FakeHybridTranscriptionAdapter.swift
//  MuesliTests
//
//  Test adapter for file (batch) transcription. Returns a canned string
//  or throws a stub error so tests never reach a real backend.
//

import Foundation
@testable import Muesli

final class FakeHybridTranscriptionAdapter: HybridTranscriptionPort {
    var stubTranscript: String = "fake transcript"
    var stubError: Error?
    private(set) var transcribeURLs: [URL] = []

    func transcribeAudioFile(url: URL) async throws -> String {
        transcribeURLs.append(url)
        if let stubError {
            throw stubError
        }
        return stubTranscript
    }
}
