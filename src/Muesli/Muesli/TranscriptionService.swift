//
//  TranscriptionService.swift
//  Muesli
//
//  Deepgram transcription service with real-time and batch processing
//

import Foundation
import AVFoundation
import SwiftUI

enum TranscriptionError: Error, LocalizedError {
    case invalidAPIKey
    case networkError
    case invalidAudioFile
    case decodingError
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Deepgram API key"
        case .networkError:
            return "Network error during transcription"
        case .invalidAudioFile:
            return "Invalid audio file"
        case .decodingError:
            return "Failed to decode transcription response"
        case .serviceUnavailable:
            return "Transcription service unavailable"
        }
    }
}

struct TranscriptionResult {
    let text: String
    let confidence: Double
    let isFinal: Bool
    let timestamp: TimeInterval
}

struct DeepgramResponse: Codable {
    let results: DeepgramResults
}

struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double
}

@Observable
class TranscriptionService {
    
    static let shared = TranscriptionService()
    
    // Configuration
    private let baseURL = "https://api.deepgram.com/v1"
    private var apiKey: String?
    
    // Real-time transcription state
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    
    // Published properties
    private(set) var isTranscribing: Bool = false
    private(set) var currentTranscript: String = ""
    private(set) var hasValidAPIKey: Bool = false
    
    // Callbacks
    var onTranscriptionUpdate: ((TranscriptionResult) -> Void)?
    var onError: ((Error) -> Void)?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
        
        loadAPIKey()
    }
    
    // MARK: - Configuration
    
    func setAPIKey(_ key: String) {
        apiKey = key
        hasValidAPIKey = !key.isEmpty
        saveAPIKey(key)
        AppLogger.shared.info("Deepgram API key configured")
    }
    
    private func loadAPIKey() {
        if let key = UserDefaults.standard.string(forKey: "DeepgramAPIKey") {
            apiKey = key
            hasValidAPIKey = !key.isEmpty
        }
    }
    
    private func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "DeepgramAPIKey")
    }
    
    // MARK: - Real-time Transcription
    
    func startRealtimeTranscription() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw TranscriptionError.invalidAPIKey
        }
        
        guard NetworkMonitor.shared.isConnected else {
            throw TranscriptionError.networkError
        }
        
        // Deepgram WebSocket URL for real-time transcription
        let urlString = "\(baseURL)/listen?model=nova-2&language=en&smart_format=true&interim_results=true"
        guard let url = URL(string: urlString.replacingOccurrences(of: "https://", with: "wss://")) else {
            throw TranscriptionError.serviceUnavailable
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isTranscribing = true
        currentTranscript = ""
        
        // Start listening for messages
        await startListening()
        
        AppLogger.shared.info("Started real-time transcription")
    }
    
    func stopRealtimeTranscription() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isTranscribing = false
        AppLogger.shared.info("Stopped real-time transcription")
    }
    
    func sendAudioData(_ data: Data) async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            try await webSocketTask.send(.data(data))
        } catch {
            AppLogger.shared.error("Failed to send audio data", error: error)
            onError?(error)
        }
    }
    
    private func startListening() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            await handleWebSocketMessage(message)
            
            // Continue listening if still connected
            if isTranscribing {
                await startListening()
            }
        } catch {
            AppLogger.shared.error("WebSocket receive error", error: error)
            onError?(error)
            isTranscribing = false
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await processTranscriptionResponse(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await processTranscriptionResponse(text)
            }
        @unknown default:
            break
        }
    }
    
    private func processTranscriptionResponse(_ jsonString: String) async {
        do {
            guard let data = jsonString.data(using: .utf8) else { return }
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            if let channel = response.results.channels.first,
               let alternative = channel.alternatives.first {
                
                let result = TranscriptionResult(
                    text: alternative.transcript,
                    confidence: alternative.confidence,
                    isFinal: true, // Deepgram doesn't explicitly mark final in this format
                    timestamp: Date().timeIntervalSince1970
                )
                
                DispatchQueue.main.async {
                    self.currentTranscript = alternative.transcript
                    self.onTranscriptionUpdate?(result)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to decode transcription response", error: error)
        }
    }
    
    // MARK: - Batch Transcription
    
    func transcribeAudioFile(url: URL) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw TranscriptionError.invalidAPIKey
        }
        
        guard NetworkMonitor.shared.isConnected else {
            throw TranscriptionError.networkError
        }
        
        let transcriptionURL = URL(string: "\(baseURL)/listen?model=nova-2&smart_format=true")!
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Content-Type")
        
        do {
            let audioData = try Data(contentsOf: url)
            request.httpBody = audioData
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw TranscriptionError.serviceUnavailable
            }
            
            let deepgramResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            if let channel = deepgramResponse.results.channels.first,
               let alternative = channel.alternatives.first {
                AppLogger.shared.info("Successfully transcribed audio file")
                return alternative.transcript
            } else {
                throw TranscriptionError.decodingError
            }
            
        } catch {
            AppLogger.shared.error("Batch transcription failed", error: error)
            throw error
        }
    }
    
    // MARK: - Utility Methods
    
    func isConfigured() -> Bool {
        return hasValidAPIKey && NetworkMonitor.shared.isConnected
    }
}
