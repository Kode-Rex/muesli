//
//  FakeTranscriptionAdapter.swift
//  MuesliTests
//
//  In-memory transcription adapter for tests. Never hits the network.
//  Records start/stop calls so tests can assert on behavior.
//

import Foundation
@testable import Muesli

final class FakeTranscriptionAdapter: TranscriptionPort {
    // Configurable per-test
    var stubHasValidEndpoint: Bool = true
    var stubStartReturns: Bool = false
    var stubFileTranscript: String? = nil

    // Recorded calls
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var transcribeFileURLs: [URL] = []

    // Port surface
    var isTranscribing: Bool = false
    var hasValidAPIEndpoint: Bool { stubHasValidEndpoint }
    var environmentName: String { "test" }
    var currentAPIEndpoint: String { "https://test.local" }
    var isUsingLocalhost: Bool { false }

    var onError: ((Error) -> Void)?
    var onTranscriptionUpdate: ((TranscriptionResult) -> Void)?

    func startRealtimeTranscription() async -> Bool {
        startCount += 1
        if stubStartReturns {
            isTranscribing = true
        }
        return stubStartReturns
    }

    func stopRealtimeTranscription() {
        stopCount += 1
        isTranscribing = false
    }

    func transcribeAudioFile(url: URL) async -> String? {
        transcribeFileURLs.append(url)
        return stubFileTranscript
    }
}
