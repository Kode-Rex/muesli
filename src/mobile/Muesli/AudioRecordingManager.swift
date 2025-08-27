//
//  AudioRecordingManager.swift
//  Muesli
//
//  Audio recording manager with AVFoundation
//

import Foundation
import AVFoundation
import SwiftUI

enum RecordingState {
    case idle
    case recording
    case paused
    case finished
}

enum RecordingError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case fileNotFound
    case audioSessionError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .recordingFailed:
            return "Recording failed"
        case .fileNotFound:
            return "Audio file not found"
        case .audioSessionError:
            return "Audio session error"
        }
    }
}

@Observable
class AudioRecordingManager: NSObject {
    
    static let shared = AudioRecordingManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // Published properties
    private(set) var state: RecordingState = .idle
    private(set) var currentRecordingPath: String?
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var hasPermission: Bool = false
    
    // Timer for updating duration
    private var durationTimer: Timer?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func checkPermission() {
        switch audioSession.recordPermission {
        case .granted:
            hasPermission = true
        case .denied, .undetermined:
            hasPermission = false
        @unknown default:
            hasPermission = false
        }
    }
    
    // MARK: - Recording Controls
    
    func startRecording(fileName: String? = nil) async throws -> String {
        guard hasPermission else {
            throw RecordingError.permissionDenied
        }
        
        // Generate file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = fileName ?? "recording_\(UUID().uuidString).m4a"
        let audioURL = documentsPath.appendingPathComponent(audioFilename)
        
        // Audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            if success {
                state = .recording
                currentRecordingPath = audioFilename
                recordingDuration = 0
                startDurationTimer()
                AppLogger.shared.info("Started recording: \(audioFilename)")
                return audioFilename
            } else {
                throw RecordingError.recordingFailed
            }
        } catch {
            AppLogger.shared.error("Failed to start recording", error: error)
            throw RecordingError.recordingFailed
        }
    }
    
    func pauseRecording() {
        guard state == .recording else { return }
        
        audioRecorder?.pause()
        state = .paused
        stopDurationTimer()
        AppLogger.shared.info("Paused recording")
    }
    
    func resumeRecording() {
        guard state == .paused else { return }
        
        audioRecorder?.record()
        state = .recording
        startDurationTimer()
        AppLogger.shared.info("Resumed recording")
    }
    
    func stopRecording() {
        guard state == .recording || state == .paused else { return }
        
        audioRecorder?.stop()
        state = .finished
        stopDurationTimer()
        
        do {
            try audioSession.setActive(false)
        } catch {
            AppLogger.shared.warning("Failed to deactivate audio session: \(error)")
        }
        
        AppLogger.shared.info("Stopped recording. Duration: \(recordingDuration)s")
    }
    
    func cancelRecording() {
        guard state == .recording || state == .paused else { return }
        
        audioRecorder?.stop()
        state = .idle
        stopDurationTimer()
        
        // Delete the recording file
        if let path = currentRecordingPath {
            deleteRecording(fileName: path)
        }
        
        currentRecordingPath = nil
        recordingDuration = 0
        
        do {
            try audioSession.setActive(false)
        } catch {
            AppLogger.shared.warning("Failed to deactivate audio session: \(error)")
        }
        
        AppLogger.shared.info("Cancelled recording")
    }
    
    // MARK: - File Management
    
    func deleteRecording(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: audioURL)
            AppLogger.shared.info("Deleted recording: \(fileName)")
        } catch {
            AppLogger.shared.error("Failed to delete recording: \(fileName)", error: error)
        }
    }
    
    func getRecordingURL(fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            checkPermission()
        } catch {
            AppLogger.shared.error("Failed to setup audio session", error: error)
        }
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.recordingDuration = recorder.currentTime
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingManager: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            AppLogger.shared.info("Recording finished successfully")
        } else {
            AppLogger.shared.error("Recording failed to finish")
            state = .idle
            currentRecordingPath = nil
            recordingDuration = 0
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        AppLogger.shared.error("Recording encode error", error: error)
        state = .idle
        currentRecordingPath = nil
        recordingDuration = 0
    }
}
