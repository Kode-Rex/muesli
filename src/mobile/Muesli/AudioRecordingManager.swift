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
    private(set) var audioLevel: Float = 0.0
    private(set) var averagePower: Float = 0.0
    private(set) var peakPower: Float = 0.0
    
    // Timer for updating duration and audio levels
    private var durationTimer: Timer?
    private var recordingStartTime: Date?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func checkPermission() {
        switch AVAudioApplication.shared.recordPermission {
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
        
        // Stop any existing recording first
        if audioRecorder?.isRecording == true {
            AppLogger.shared.info("Stopping existing recording before starting new one")
            audioRecorder?.stop()
        }
        
        // Generate file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = fileName ?? "recording_\(UUID().uuidString).wav"
        let audioURL = documentsPath.appendingPathComponent(audioFilename)
        
        // Audio recording settings - using more compatible format for iOS Simulator
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), // Use uncompressed PCM for better compatibility
            AVSampleRateKey: 44100.0, // Standard sample rate
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            // Use simpler, more compatible audio session configuration
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            // Add a small delay to let audio session stabilize
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Ensure prepareToRecord succeeds
            guard let recorder = audioRecorder else {
                AppLogger.shared.error("Failed to create AVAudioRecorder")
                throw RecordingError.recordingFailed
            }
            
            guard recorder.prepareToRecord() else {
                AppLogger.shared.error("Failed to prepare recorder - URL: \(audioURL), Settings: \(settings)")
                throw RecordingError.recordingFailed
            }
            
            // Add a small delay before starting recording
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            let success = audioRecorder?.record() ?? false
            if success {
                recordingStartTime = Date()
                DispatchQueue.main.async {
                    self.state = .recording
                    self.currentRecordingPath = audioFilename
                    self.recordingDuration = 0
                }
                
                // Verify recording actually started
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                if audioRecorder?.isRecording == true {
                    startDurationTimer()
                    AppLogger.shared.info("Started recording: \(audioFilename) - Verified recording is active")
                    return audioFilename
                } else {
                    AppLogger.shared.error("Recording failed to start properly - isRecording is false")
                    throw RecordingError.recordingFailed
                }
            } else {
                AppLogger.shared.error("record() returned false")
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
        DispatchQueue.main.async {
            self.state = .paused
        }
        // Keep timer running to track duration even when paused
        AppLogger.shared.info("Paused recording")
    }
    
    func resumeRecording() {
        guard state == .paused else { return }
        
        // Ensure audio session is still active
        do {
            try audioSession.setActive(true)
        } catch {
            AppLogger.shared.warning("Failed to reactivate audio session on resume: \(error)")
        }
        
        audioRecorder?.record()
        DispatchQueue.main.async {
            self.state = .recording
        }
        // Timer should already be running
        AppLogger.shared.info("Resumed recording")
    }
    
    func stopRecording() {
        guard state == .recording || state == .paused else { 
            AppLogger.shared.warning("stopRecording called but state is: \(state)")
            return 
        }
        
        AppLogger.shared.info("stopRecording called - current duration: \(recordingDuration)s, state: \(state)")
        
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.state = .finished
        }
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
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            checkPermission()
        } catch {
            AppLogger.shared.error("Failed to setup audio session", error: error)
        }
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        AppLogger.shared.info("Starting duration timer with 0.1s interval")
        
        // Ensure timer is created on main thread and added to main run loop
        DispatchQueue.main.async {
            self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self else { 
                    AppLogger.shared.warning("Timer callback: self is nil")
                    timer.invalidate()
                    return 
                }
                
                // Debug: Log first few timer fires
                if self.recordingDuration < 1.0 {
                    AppLogger.shared.info("Timer fired - duration: \(self.recordingDuration), state: \(self.state)")
                }
                
                guard let recorder = self.audioRecorder else { 
                    AppLogger.shared.warning("Timer callback: recorder is nil")
                    return 
                }
                
                // Check if recorder is actually recording
                guard recorder.isRecording else {
                    AppLogger.shared.warning("Timer callback: recorder.isRecording is false - stopping timer updates")
                    return
                }
                
                // Log every 10th callback (every 1 second) and first few callbacks
                let currentTime = recorder.currentTime
                let callbackCount = Int(currentTime * 10)
                if callbackCount % 10 == 0 || callbackCount < 10 {
                    AppLogger.shared.info("Timer callback #\(callbackCount): currentTime=\(currentTime), state=\(self.state), isRecording=\(recorder.isRecording)")
                }
                
                // Update duration and audio levels (already on main thread)
                self.recordingDuration = recorder.currentTime
                
                // Only update audio levels when actively recording
                if self.state == .recording && recorder.isRecording {
                    recorder.updateMeters()
                    self.averagePower = recorder.averagePower(forChannel: 0)
                    self.peakPower = recorder.peakPower(forChannel: 0)
                    
                    // Normalize audio level (0.0 to 1.0)
                    // Average power ranges from -160 dB (silence) to 0 dB (max)
                    // Map -50 dB to 0.0 and 0 dB to 1.0 for better visual range
                    let minDB: Float = -50.0
                    let maxDB: Float = 0.0
                    let clampedPower = max(minDB, min(maxDB, self.averagePower))
                    let normalizedLevel = (clampedPower - minDB) / (maxDB - minDB)
                    self.audioLevel = normalizedLevel
                    
                    // Debug audio levels for first few seconds
                    if self.recordingDuration < 3.0 && callbackCount % 5 == 0 {
                        AppLogger.shared.info("Audio levels - avgPower: \(self.averagePower), peakPower: \(self.peakPower), normalizedLevel: \(normalizedLevel), audioLevel: \(self.audioLevel)")
                    }
                } else {
                    // Reset audio levels when paused
                    self.audioLevel = 0.0
                    self.averagePower = 0.0
                    self.peakPower = 0.0
                }
            }
            
            // Add timer to current run loop to ensure it fires
            if let timer = self.durationTimer {
                RunLoop.current.add(timer, forMode: .common)
                AppLogger.shared.info("Duration timer created and added to run loop successfully")
            } else {
                AppLogger.shared.error("Failed to create duration timer")
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        
        // Reset audio levels when not recording
        audioLevel = 0.0
        averagePower = 0.0
        peakPower = 0.0
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingManager: AVAudioRecorderDelegate {
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if recorder.currentTime < 1.0 {
            AppLogger.shared.warning("Recording finished too quickly - possible audio session conflict or simulator limitation")
        }

        Task { @MainActor in
            if flag {
                AppLogger.shared.info("Recording finished successfully")
                self.state = .finished
            } else {
                AppLogger.shared.error("Recording failed to finish")
                self.state = .idle
                self.currentRecordingPath = nil
                self.recordingDuration = 0
                self.stopDurationTimer()
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        AppLogger.shared.error("Recording encode error", error: error)

        Task { @MainActor in
            self.state = .idle
            self.currentRecordingPath = nil
            self.recordingDuration = 0
            self.stopDurationTimer()

            do {
                try self.audioSession.setActive(false)
            } catch {
                AppLogger.shared.warning("Failed to deactivate audio session after encode error: \(error)")
            }
        }
    }
}

