//
//  HybridTranscriptionService.swift
//  Muesli
//
//  Smart hybrid transcription that uses iOS for short recordings
//  and Deepgram for longer sessions
//

import Foundation
import AVFoundation
import SwiftUI

enum TranscriptionStrategy {
    case local      // iOS Speech framework (on-device)
    case cloud      // Deepgram via API
    case automatic  // Smart selection based on recording length

    var displayName: String {
        switch self {
        case .local: return "On-Device"
        case .cloud: return "Cloud (Deepgram)"
        case .automatic: return "Automatic (Smart)"
        }
    }
}

enum HybridTranscriptionError: Error, LocalizedError {
    case allServicesUnavailable
    case recordingTooLong
    case noAvailableService

    var errorDescription: String? {
        switch self {
        case .allServicesUnavailable:
            return "Both local and cloud transcription are unavailable"
        case .recordingTooLong:
            return "Recording too long for available transcription services"
        case .noAvailableService:
            return "No transcription service available"
        }
    }
}

@Observable
class HybridTranscriptionService {

    static let shared = HybridTranscriptionService()

    // Service instances
    private let localService = LocalTranscriptionService.shared
    private let cloudService = TranscriptionService.shared

    // Configuration
    private let shortRecordingThreshold = AppConstants.Transcription.shortRecordingThreshold
    private(set) var currentStrategy: TranscriptionStrategy = .automatic
    private(set) var activeService: String = "None"

    // State
    private(set) var isTranscribing: Bool = false
    private(set) var currentTranscript: String = ""
    private var recordingStartTime: Date?
    private var selectedStrategy: TranscriptionStrategy = .automatic

    // Callbacks
    var onTranscriptionUpdate: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?

    private init() {
        setupServiceCallbacks()

        // Request Speech Recognition permission if not already granted
        Task {
            if !localService.hasPermission {
                let granted = await localService.requestPermissions()
                if granted {
                    AppLogger.shared.info("Speech Recognition permission granted")
                } else {
                    AppLogger.shared.warning("Speech Recognition permission denied - will use cloud only")
                }
            }
        }
    }

    private func setupServiceCallbacks() {
        // Local service callbacks
        localService.onTranscriptionUpdate = { [weak self] transcript, isFinal in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentTranscript = transcript
                self.onTranscriptionUpdate?(transcript, isFinal)
            }
        }

        localService.onError = { [weak self] error in
            guard let self = self else { return }
            AppLogger.shared.warning("Local transcription error: \(error.localizedDescription)")

            // Attempt fallback to cloud if local fails
            Task {
                await self.fallbackToCloud(error: error)
            }
        }

        // Cloud service callbacks
        cloudService.onTranscriptionUpdate = { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentTranscript = result.text
                self.onTranscriptionUpdate?(result.text, result.isFinal)
            }
        }

        cloudService.onError = { [weak self] error in
            guard let self = self else { return }
            AppLogger.shared.warning("Cloud transcription error: \(error.localizedDescription)")

            // Attempt fallback to local if cloud fails
            Task {
                await self.fallbackToLocal(error: error)
            }
        }
    }

    // MARK: - Configuration

    func setStrategy(_ strategy: TranscriptionStrategy) {
        selectedStrategy = strategy
        AppLogger.shared.info("Transcription strategy set to: \(strategy.displayName)")
    }

    var isLocalAvailable: Bool {
        return localService.isAvailable && localService.hasPermission
    }

    var isCloudAvailable: Bool {
        return cloudService.isConfigured()
    }

    // MARK: - Real-time Transcription

    func startRealtimeTranscription() async throws {
        recordingStartTime = Date()
        isTranscribing = true
        currentTranscript = ""

        let strategy = determineStrategy(estimatedDuration: nil)
        currentStrategy = strategy

        AppLogger.shared.info("Starting transcription with strategy: \(strategy.displayName)")

        switch strategy {
        case .local:
            try await startLocalTranscription()
        case .cloud:
            try await startCloudTranscription()
        case .automatic:
            // Start with local for automatic mode, will switch if needed
            try await startLocalTranscription()
        }
    }

    func stopRealtimeTranscription() {
        // Stop both services (only active one will actually do something)
        localService.stopRealtimeTranscription()
        cloudService.stopRealtimeTranscription()

        isTranscribing = false
        recordingStartTime = nil
        activeService = "None"

        AppLogger.shared.info("Stopped hybrid transcription")
    }

    private func startLocalTranscription() async throws {
        guard isLocalAvailable else {
            AppLogger.shared.warning("Local transcription not available, trying cloud...")
            try await startCloudTranscription()
            return
        }

        do {
            try await localService.startRealtimeTranscription()
            activeService = "Local (iOS Speech)"
            AppLogger.shared.info("Using local transcription service")
        } catch {
            AppLogger.shared.error("Local transcription failed to start", error: error)
            // Try cloud as fallback
            try await startCloudTranscription()
        }
    }

    private func startCloudTranscription() async throws {
        guard isCloudAvailable else {
            AppLogger.shared.warning("Cloud transcription not available, trying local...")

            if isLocalAvailable {
                try await startLocalTranscription()
                return
            }

            throw HybridTranscriptionError.allServicesUnavailable
        }

        let success = await cloudService.startRealtimeTranscription()
        if success {
            activeService = "Cloud (Deepgram)"
            AppLogger.shared.info("Using cloud transcription service")
        } else {
            AppLogger.shared.warning("Cloud transcription failed to start")

            // Try local as fallback
            if isLocalAvailable {
                try await startLocalTranscription()
            } else {
                throw HybridTranscriptionError.noAvailableService
            }
        }
    }

    // MARK: - Batch Transcription

    func transcribeAudioFile(url: URL) async throws -> String {
        // Check if file exists first
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.shared.error("Audio file does not exist at path: \(url.path)")
            throw HybridTranscriptionError.noAvailableService
        }

        // Determine duration of the audio file
        let duration: TimeInterval
        do {
            duration = try await getAudioDuration(url: url)
        } catch {
            AppLogger.shared.warning("Could not determine audio duration, assuming short recording: \(error.localizedDescription)")
            // Assume short duration if we can't read it - use local
            duration = 30.0 // Default to 30 seconds
        }

        let strategy = determineStrategy(estimatedDuration: duration)

        AppLogger.shared.info("Transcribing file with strategy: \(strategy.displayName) (duration: \(Int(duration))s)")

        switch strategy {
        case .local:
            return try await transcribeWithLocal(url: url)
        case .cloud:
            return try await transcribeWithCloud(url: url)
        case .automatic:
            if duration < shortRecordingThreshold {
                return try await transcribeWithLocal(url: url)
            } else {
                return try await transcribeWithCloud(url: url)
            }
        }
    }

    private func transcribeWithLocal(url: URL) async throws -> String {
        guard isLocalAvailable else {
            AppLogger.shared.warning("Local transcription not available, trying cloud...")
            return try await transcribeWithCloud(url: url)
        }

        do {
            let transcript = try await localService.transcribeAudioFile(url: url)
            AppLogger.shared.info("File transcribed successfully with local service: \(transcript.count) chars")
            return transcript
        } catch {
            AppLogger.shared.error("Local file transcription failed", error: error)

            // Try cloud as fallback
            if isCloudAvailable {
                AppLogger.shared.info("Falling back to cloud transcription for file")
                return try await transcribeWithCloud(url: url)
            }

            throw error
        }
    }

    private func transcribeWithCloud(url: URL) async throws -> String {
        guard isCloudAvailable else {
            AppLogger.shared.warning("Cloud transcription not available, trying local...")

            if isLocalAvailable {
                return try await transcribeWithLocal(url: url)
            }

            throw HybridTranscriptionError.allServicesUnavailable
        }

        if let transcript = await cloudService.transcribeAudioFile(url: url) {
            AppLogger.shared.info("File transcribed successfully with cloud service: \(transcript.count) chars")
            return transcript
        } else {
            AppLogger.shared.warning("Cloud file transcription returned nil")

            // Try local as fallback
            if isLocalAvailable {
                AppLogger.shared.info("Falling back to local transcription for file")
                return try await transcribeWithLocal(url: url)
            }

            throw HybridTranscriptionError.noAvailableService
        }
    }

    // MARK: - Strategy Selection

    private func determineStrategy(estimatedDuration: TimeInterval?) -> TranscriptionStrategy {
        // If user has set a specific strategy, use it
        if selectedStrategy != .automatic {
            return selectedStrategy
        }

        // Automatic selection logic
        if let duration = estimatedDuration {
            // For short recordings, prefer local
            if duration < shortRecordingThreshold {
                return isLocalAvailable ? .local : .cloud
            } else {
                // For longer recordings, prefer cloud
                return isCloudAvailable ? .cloud : .local
            }
        }

        // Default: prefer local for privacy and offline capability
        return isLocalAvailable ? .local : .cloud
    }

    // MARK: - Fallback Logic

    private func fallbackToCloud(error: Error) async {
        guard isTranscribing else { return }
        guard isCloudAvailable else {
            onError?(error)
            return
        }

        AppLogger.shared.info("Attempting fallback from local to cloud transcription")

        do {
            localService.stopRealtimeTranscription()
            try await startCloudTranscription()
        } catch {
            AppLogger.shared.error("Fallback to cloud failed", error: error)
            onError?(error)
        }
    }

    private func fallbackToLocal(error: Error) async {
        guard isTranscribing else { return }
        guard isLocalAvailable else {
            onError?(error)
            return
        }

        AppLogger.shared.info("Attempting fallback from cloud to local transcription")

        do {
            cloudService.stopRealtimeTranscription()
            try await startLocalTranscription()
        } catch {
            AppLogger.shared.error("Fallback to local failed", error: error)
            onError?(error)
        }
    }

    // MARK: - Duration Monitoring

    func checkAndSwitchIfNeeded() async {
        guard currentStrategy == .automatic else { return }
        guard let startTime = recordingStartTime else { return }

        let currentDuration = Date().timeIntervalSince(startTime)

        // If we've been recording for more than threshold on local, switch to cloud
        if activeService.contains("Local") && currentDuration > shortRecordingThreshold {
            AppLogger.shared.info("Recording exceeded threshold (\(Int(shortRecordingThreshold))s), switching to cloud")

            do {
                localService.stopRealtimeTranscription()
                try await startCloudTranscription()
            } catch {
                AppLogger.shared.warning("Failed to switch to cloud, continuing with local")
            }
        }
    }

    // MARK: - Utilities

    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    var statusDescription: String {
        if !isTranscribing {
            return "Ready"
        }

        var status = "Active: \(activeService)"

        if let startTime = recordingStartTime {
            let duration = Int(Date().timeIntervalSince(startTime))
            let minutes = duration / 60
            let seconds = duration % 60
            status += " (\(minutes)m \(seconds)s)"
        }

        return status
    }

    var thresholdDescription: String {
        let minutes = Int(shortRecordingThreshold / 60)
        return "\(minutes) minutes"
    }
}
