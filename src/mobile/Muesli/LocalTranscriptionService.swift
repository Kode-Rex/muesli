//
//  LocalTranscriptionService.swift
//  Muesli
//
//  Created by Kiro on 9/8/25.
//

import Foundation
import Speech
import AVFoundation

enum LocalTranscriptionError: Error, LocalizedError {
    case speechRecognitionNotAvailable
    case permissionDenied
    case audioFileNotFound
    case recognitionFailed
    case unsupportedLanguage

    var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAvailable:
            return "Speech recognition not available on this device"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .audioFileNotFound:
            return "Audio file not found"
        case .recognitionFailed:
            return "Speech recognition failed"
        case .unsupportedLanguage:
            return "Language not supported for speech recognition"
        }
    }
}

@Observable
class LocalTranscriptionService: NSObject {
    static let shared = LocalTranscriptionService()

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Published properties
    private(set) var isTranscribing: Bool = false
    private(set) var hasPermission: Bool = false
    private(set) var isAvailable: Bool = false
    private(set) var currentTranscript: String = ""

    // Callbacks
    var onTranscriptionUpdate: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?

    override private init() {
        // Initialize with device locale, fallback to English
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        isAvailable = speechRecognizer?.isAvailable ?? false

        super.init()

        // Monitor availability changes
        speechRecognizer?.delegate = self

        checkPermissions()
    }

    // MARK: - Permission Management

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechPermission = await requestSpeechPermission()

        // Request microphone permission (if not already granted)
        let micPermission = await AudioRecordingManager.shared.requestPermission()

        let granted = speechPermission && micPermission
        await MainActor.run {
            hasPermission = granted
        }

        AppLogger.shared.info("Local transcription permissions - Speech: \(speechPermission), Microphone: \(micPermission)")
        return granted
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                continuation.resume(returning: granted)
            }
        }
    }

    private func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        hasPermission = speechStatus == .authorized && micStatus == .granted
    }

    // MARK: - Real-time Transcription

    func startRealtimeTranscription() async throws {
        guard isAvailable else {
            throw LocalTranscriptionError.speechRecognitionNotAvailable
        }

        guard hasPermission else {
            throw LocalTranscriptionError.permissionDenied
        }

        // Stop any existing transcription
        if isTranscribing {
            stopRealtimeTranscription()
        }

        try await setupAudioSession()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw LocalTranscriptionError.recognitionFailed
        }

        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                AppLogger.shared.error("Speech recognition error", error: error)
                DispatchQueue.main.async {
                    self.onError?(error)
                    self.stopRealtimeTranscription()
                }
                return
            }

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                DispatchQueue.main.async {
                    self.currentTranscript = transcript
                    self.onTranscriptionUpdate?(transcript, isFinal)
                }

                if isFinal {
                    AppLogger.shared.info("Final transcription result: \(transcript.prefix(50))...")
                }
            }
        }

        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        await MainActor.run {
            isTranscribing = true
            currentTranscript = ""
        }

        AppLogger.shared.info("Started local real-time transcription")
    }

    func stopRealtimeTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isTranscribing = false

        AppLogger.shared.info("Stopped local real-time transcription")
    }

    // MARK: - File Transcription

    func transcribeAudioFile(url: URL) async throws -> String {
        guard isAvailable else {
            throw LocalTranscriptionError.speechRecognitionNotAvailable
        }

        guard hasPermission else {
            throw LocalTranscriptionError.permissionDenied
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalTranscriptionError.audioFileNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }

            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    AppLogger.shared.error("File transcription error", error: error)
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    AppLogger.shared.info("File transcription completed: \(transcript.count) characters")
                    continuation.resume(returning: transcript)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension LocalTranscriptionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
            AppLogger.shared.info("Speech recognizer availability changed: \(available)")

            if !available && self.isTranscribing {
                self.stopRealtimeTranscription()
            }
        }
    }
}
