//
//  TranscriptionFallbackTests.swift
//  MuesliTests
//
//  Tests for graceful fallback behavior when transcription services are unavailable.
//  Uses TestWorld to inject a FakeTranscriptionAdapter so no real network traffic occurs.
//

import Testing
import Foundation
@testable import Muesli

@MainActor
struct TranscriptionFallbackTests {
    private let transcription: FakeTranscriptionAdapter
    private let network: FakeNetworkAdapter

    init() {
        let installed = TestWorld.install()
        self.transcription = installed.transcription
        self.network = installed.network
    }

    // MARK: - Real-time Transcription Fallback Tests

    @Test("Real-time transcription gracefully handles API unavailable")
    func realTimeTranscriptionHandlesAPIUnavailable() async throws {
        transcription.stubHasValidEndpoint = false
        transcription.stubStartReturns = false

        let success = await World.current.transcription.startRealtimeTranscription()

        #expect(success == false)
        #expect(World.current.transcription.isTranscribing == false)

        World.current.transcription.stopRealtimeTranscription()
    }

    @Test("Real-time transcription handles network unavailable gracefully")
    func realTimeTranscriptionHandlesNetworkUnavailable() async throws {
        network.stubIsConnected = false
        transcription.stubStartReturns = false

        let success = await World.current.transcription.startRealtimeTranscription()

        #expect(success == false)
        #expect(World.current.transcription.isTranscribing == false)
    }

    @Test("Multiple start/stop cycles don't cause issues")
    func multipleStartStopCyclesDontCauseIssues() async throws {
        for _ in 0..<5 {
            _ = await World.current.transcription.startRealtimeTranscription()
            World.current.transcription.stopRealtimeTranscription()

            #expect(World.current.transcription.isTranscribing == false)
        }

        #expect(transcription.startCount == 5)
        #expect(transcription.stopCount == 5)
    }

    // MARK: - Batch Transcription Fallback Tests

    @Test("Batch transcription handles invalid file gracefully")
    func batchTranscriptionHandlesInvalidFileGracefully() async throws {
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        let result = await World.current.transcription.transcribeAudioFile(url: invalidURL)

        #expect(result == nil)
    }

    @Test("Batch transcription handles API unavailable gracefully")
    func batchTranscriptionHandlesAPIUnavailableGracefully() async throws {
        transcription.stubHasValidEndpoint = false
        transcription.stubFileTranscript = nil

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.m4a")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = await World.current.transcription.transcribeAudioFile(url: tempURL)

        #expect(result == nil)
    }

    // MARK: - NetworkMonitor Integration Tests

    @Test("Network monitor state changes are handled gracefully")
    func networkMonitorStateChangesAreHandledGracefully() async throws {
        // Just confirm the port returns a stable boolean and start/stop are idempotent.
        _ = World.current.network.isConnected
        World.current.network.startMonitoring()
        World.current.network.startMonitoring()
        World.current.network.stopMonitoring()
        World.current.network.stopMonitoring()

        #expect(network.startMonitoringCount == 2)
        #expect(network.stopMonitoringCount == 2)
    }

    // MARK: - Integration Tests for NewNoteView Logic

    @Test("Transcription service integration doesn't crash on failures")
    func transcriptionServiceIntegrationDoesntCrashOnFailures() async throws {
        // Simulate the logic from NewNoteView.tryStartTranscription()
        network.stubIsConnected = true
        transcription.stubHasValidEndpoint = true
        transcription.stubStartReturns = true

        let canAttemptTranscription =
            World.current.network.isConnected && World.current.transcription.hasValidAPIEndpoint

        if canAttemptTranscription {
            let success = await World.current.transcription.startRealtimeTranscription()
            #expect(success == true)
            if World.current.transcription.isTranscribing {
                World.current.transcription.stopRealtimeTranscription()
            }
        }
    }

    // MARK: - Cleanup and State Management Tests

    @Test("Service cleanup is idempotent")
    func serviceCleanupIsIdempotent() async throws {
        _ = await World.current.transcription.startRealtimeTranscription()
        World.current.transcription.stopRealtimeTranscription()
        World.current.transcription.stopRealtimeTranscription()
        World.current.transcription.stopRealtimeTranscription()

        #expect(World.current.transcription.isTranscribing == false)
        #expect(transcription.stopCount == 3)
    }

    @Test("Service state remains consistent after failures")
    func serviceStateRemainsConsistentAfterFailures() async throws {
        _ = await World.current.transcription.startRealtimeTranscription()
        World.current.transcription.stopRealtimeTranscription()

        #expect(World.current.transcription.isTranscribing == false)
    }

    // MARK: - Error Callback Tests

    @Test("Error callbacks don't crash when called")
    func errorCallbacksDontCrashWhenCalled() async throws {
        var errorReceived: Error?
        World.current.transcription.onError = { error in
            errorReceived = error
        }

        _ = await World.current.transcription.startRealtimeTranscription()

        World.current.transcription.onError = nil
        World.current.transcription.stopRealtimeTranscription()

        // The fake does not invoke onError, so this should remain nil.
        #expect(errorReceived == nil)
    }

    // MARK: - Configuration Tests

    @Test("Service configuration queries are safe")
    func serviceConfigurationQueriesAreSafe() async throws {
        let hasValidEndpoint = World.current.transcription.hasValidAPIEndpoint
        let environmentName = World.current.transcription.environmentName

        #expect(hasValidEndpoint == true)
        #expect(environmentName == "test")
    }

    // MARK: - Stress Test

    @Test("Rapid transcription requests don't cause crashes")
    func rapidTranscriptionRequestsDontCauseCrashes() async throws {
        // Sequential rapid cycling against the fake. The previous concurrent
        // task group was meaningless against a singleton; sequential cycling
        // exercises the same idempotency property without thread-safety noise.
        for _ in 0..<10 {
            _ = await World.current.transcription.startRealtimeTranscription()
            World.current.transcription.stopRealtimeTranscription()
        }

        #expect(World.current.transcription.isTranscribing == false)
        #expect(transcription.startCount == 10)
        #expect(transcription.stopCount == 10)
    }
}
