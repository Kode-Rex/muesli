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
    case apiEndpointNotConfigured
    case networkError
    case invalidAudioFile
    case decodingError
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .apiEndpointNotConfigured:
            return "Transcription API endpoint not configured"
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
class TranscriptionService: TranscriptionPort {

    static let shared = TranscriptionService()
    
    // Configuration
    private var urlSession: URLSession
    private var currentAPIBaseURL: String = ""
    
    // Real-time transcription state
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Published properties
    private(set) var isTranscribing: Bool = false
    private(set) var currentTranscript: String = ""
    private(set) var hasValidAPIEndpoint: Bool = false
    
    // Callbacks
    var onTranscriptionUpdate: ((TranscriptionResult) -> Void)?
    var onError: ((Error) -> Void)?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
        
        Task {
            await loadAPIConfiguration()
        }
    }
    
    private func loadAPIConfiguration() async {
        currentAPIBaseURL = await APIConfiguration.getCurrentAPIURL()
        await MainActor.run {
            hasValidAPIEndpoint = !currentAPIBaseURL.isEmpty
        }
    }
    
    // MARK: - Configuration
    
    var currentAPIEndpoint: String {
        return currentAPIBaseURL
    }
    
    var isUsingLocalhost: Bool {
        return currentAPIBaseURL.contains("localhost") || currentAPIBaseURL.contains("127.0.0.1")
    }
    
    var environmentName: String {
        return APIConfiguration.environmentName
    }
    
    // MARK: - Real-time Transcription
    
    func startRealtimeTranscription() async -> Bool {
        guard hasValidAPIEndpoint else {
            AppLogger.shared.info("Transcription API endpoint not configured - using local recording mode")
            return false
        }
        
        guard NetworkMonitor.shared.isConnected else {
            AppLogger.shared.warning("Network not available - falling back to local recording")
            return false
        }
        
        // Stop any existing connection first
        if webSocketTask != nil {
            AppLogger.shared.info("Stopping existing WebSocket connection before starting new one")
            stopRealtimeTranscription()
        }
        
        // Your API WebSocket endpoint for real-time transcription
        let urlString = "\(currentAPIBaseURL)/transcribe/realtime"
        let wsURL = urlString.replacingOccurrences(of: "http://", with: "ws://")
                             .replacingOccurrences(of: "https://", with: "wss://")
        
        guard let url = URL(string: wsURL) else {
            AppLogger.shared.warning("Invalid WebSocket URL: \(wsURL) - falling back to local recording")
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add timeout for connection
        request.timeoutInterval = 10.0
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isTranscribing = true
        currentTranscript = ""
        
        // Start listening for messages
        await startListening()
        
        AppLogger.shared.info("Started real-time transcription via custom API at: \(wsURL)")
        return true
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
        guard let webSocketTask = webSocketTask else { 
            AppLogger.shared.warning("startListening called but webSocketTask is nil")
            return 
        }
        
        do {
            let message = try await webSocketTask.receive()
            await handleWebSocketMessage(message)
            
            // Continue listening if still connected and transcribing
            if isTranscribing && self.webSocketTask != nil {
                await startListening()
            }
        } catch {
            AppLogger.shared.info("[TranscriptionService.swift:179] startListening() - WebSocket connection lost - transcription will continue in offline mode")
            
            // Clean up the connection
            await MainActor.run {
                self.isTranscribing = false
                self.webSocketTask = nil
            }
            
            // Don't call onError for normal connection loss - just stop gracefully
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cancelled, .networkConnectionLost, .notConnectedToInternet:
                    // These are expected in mobile environments
                    AppLogger.shared.info("WebSocket closed due to network conditions: \(urlError.localizedDescription)")
                default:
                    AppLogger.shared.warning("WebSocket error: \(urlError.localizedDescription)")
                }
            } else {
                AppLogger.shared.warning("WebSocket error: \(error.localizedDescription)")
            }
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
                
                await MainActor.run {
                    self.currentTranscript = alternative.transcript
                    self.onTranscriptionUpdate?(result)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to decode transcription response", error: error)
        }
    }
    
    // MARK: - Batch Transcription
    
    func transcribeAudioFile(url: URL) async -> String? {
        guard hasValidAPIEndpoint else {
            AppLogger.shared.warning("Transcription API endpoint not configured for batch transcription")
            return nil
        }
        
        guard NetworkMonitor.shared.isConnected else {
            AppLogger.shared.warning("Network not available for batch transcription")
            return nil
        }
        
        guard let transcriptionURL = URL(string: "\(currentAPIBaseURL)/transcribe") else {
            AppLogger.shared.warning("Invalid transcription URL for batch transcription")
            return nil
        }
        
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        
        // Create multipart form data for audio file upload
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        do {
            let audioData = try Data(contentsOf: url)
            var body = Data()
            
            // Add audio file to form data
            guard let boundaryStart = "--\(boundary)\r\n".data(using: .utf8),
                  let contentDisposition = "Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8),
                  let contentType = "Content-Type: audio/wav\r\n\r\n".data(using: .utf8),
                  let boundaryEnd = "\r\n--\(boundary)--\r\n".data(using: .utf8) else {
                AppLogger.shared.warning("Failed to create form data for batch transcription")
                return nil
            }
            
            body.append(boundaryStart)
            body.append(contentDisposition)
            body.append(contentType)
            body.append(audioData)
            body.append(boundaryEnd)
            
            request.httpBody = body
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                AppLogger.shared.warning("Transcription API returned status: \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return nil
            }
            
            // Expected JSON response: {"transcript": "transcribed text"}
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let transcript = json["transcript"] as? String {
                AppLogger.shared.info("Successfully transcribed audio file via custom API")
                return transcript
            } else {
                AppLogger.shared.warning("Failed to decode batch transcription response")
                return nil
            }
            
        } catch {
            AppLogger.shared.warning("Batch transcription failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    func isConfigured() -> Bool {
        return hasValidAPIEndpoint && NetworkMonitor.shared.isConnected
    }
}

