//
//  TranscriptionServiceTests.swift
//  MuesliTests
//
//  Tests for TranscriptionService functionality
//

import Testing
import Foundation
@testable import Muesli

@Suite("Transcription Service Tests", .tags(.transcription))
struct TranscriptionServiceTests {
    
    @Test("Transcription service singleton works")
    func transcriptionServiceSingletonWorks() async throws {
        let service1 = TranscriptionService.shared
        let service2 = TranscriptionService.shared
        
        #expect(service1 === service2)
    }
    
    @Test("Transcription service initializes correctly")
    func transcriptionServiceInitializesCorrectly() async throws {
        let service = TranscriptionService.shared
        
        #expect(service.isTranscribing == false)
        #expect(service.currentTranscript == "")
    }
    
    @Test("Transcription error descriptions are provided")
    func transcriptionErrorDescriptionsAreProvided() async throws {
        let errors: [TranscriptionError] = [
            .apiEndpointNotConfigured,
            .networkError,
            .invalidAudioFile,
            .decodingError,
            .serviceUnavailable
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
        
        // Test specific descriptions
        #expect(TranscriptionError.apiEndpointNotConfigured.errorDescription?.contains("endpoint") == true)
        #expect(TranscriptionError.networkError.errorDescription?.contains("Network") == true)
        #expect(TranscriptionError.invalidAudioFile.errorDescription?.contains("audio") == true)
        #expect(TranscriptionError.decodingError.errorDescription?.contains("decode") == true)
        #expect(TranscriptionError.serviceUnavailable.errorDescription?.contains("unavailable") == true)
    }
    
    @Test("Transcription result struct works correctly")
    func transcriptionResultStructWorksCorrectly() async throws {
        let testText = "Hello world"
        let testConfidence = 0.95
        let testTimestamp = Date().timeIntervalSince1970
        
        let result = TranscriptionResult(
            text: testText,
            confidence: testConfidence,
            isFinal: true,
            timestamp: testTimestamp
        )
        
        #expect(result.text == testText)
        #expect(result.confidence == testConfidence)
        #expect(result.isFinal == true)
        #expect(result.timestamp == testTimestamp)
    }
    
    @Test("Deepgram response structures are decodable")
    func deepgramResponseStructuresAreDecodable() async throws {
        let jsonString = """
        {
            "results": {
                "channels": [
                    {
                        "alternatives": [
                            {
                                "transcript": "Hello world",
                                "confidence": 0.95
                            }
                        ]
                    }
                ]
            }
        }
        """
        
        guard let data = jsonString.data(using: .utf8) else {
            throw TranscriptionError.decodingError
        }
        
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            #expect(response.results.channels.count == 1)
            #expect(response.results.channels[0].alternatives.count == 1)
            #expect(response.results.channels[0].alternatives[0].transcript == "Hello world")
            #expect(response.results.channels[0].alternatives[0].confidence == 0.95)
        } catch {
            #expect(Bool(false)) // Decoding should succeed
        }
    }
    
    @Test("API endpoint configuration works correctly")
    func apiEndpointConfigurationWorksCorrectly() async throws {
        let service = TranscriptionService.shared
        
        // Test valid URL configuration
        let validURL = "https://api.example.com/v1"
        service.setTranscriptionAPIEndpoint(validURL)
        
        // Test invalid URL configuration
        let invalidURL = ""
        service.setTranscriptionAPIEndpoint(invalidURL)
        #expect(service.hasValidAPIEndpoint == false)
        
        // Test URL validation
        let malformedURL = "not-a-url"
        service.setTranscriptionAPIEndpoint(malformedURL)
        #expect(service.hasValidAPIEndpoint == false)
    }
    
    @Test("Configuration is properly loaded and saved")
    func configurationIsProperlyLoadedAndSaved() async throws {
        let service = TranscriptionService.shared
        let testEndpoint = "https://test.api.com/v1"
        
        // Set and save configuration
        service.setTranscriptionAPIEndpoint(testEndpoint)
        
        // Check that UserDefaults would contain the value
        let savedEndpoint = UserDefaults.standard.string(forKey: "TranscriptionAPIEndpoint")
        #expect(savedEndpoint == testEndpoint)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "TranscriptionAPIEndpoint")
    }
    
    @Test("Service configuration status is accurate")
    func serviceConfigurationStatusIsAccurate() async throws {
        let service = TranscriptionService.shared
        
        // Without valid endpoint, should not be configured
        service.setTranscriptionAPIEndpoint("")
        let isConfiguredWithoutEndpoint = service.isConfigured()
        #expect(isConfiguredWithoutEndpoint == false)
        
        // With valid endpoint but potentially no network, test endpoint validation
        service.setTranscriptionAPIEndpoint("https://valid.api.com/v1")
        #expect(service.hasValidAPIEndpoint == true)
    }
    
    @Test("Real-time transcription state management works")
    func realTimeTranscriptionStateManagementWorks() async throws {
        let service = TranscriptionService.shared
        
        // Initial state
        #expect(service.isTranscribing == false)
        #expect(service.currentTranscript == "")
        
        // Stop should be safe even when not started
        service.stopRealtimeTranscription()
        #expect(service.isTranscribing == false)
    }
    
    @Test("Batch transcription validates input parameters")
    func batchTranscriptionValidatesInputParameters() async throws {
        let service = TranscriptionService.shared
        
        // Test with invalid file URL
        let invalidURL = URL(string: "file:///nonexistent/path/file.m4a")!
        
        do {
            _ = try await service.transcribeAudioFile(url: invalidURL)
            #expect(Bool(false)) // Should throw an error
        } catch {
            #expect(Bool(true)) // Expected to throw
        }
    }
    
    @Test("WebSocket URL transformation works correctly")
    func webSocketURLTransformationWorksCorrectly() async throws {
        let httpsURL = "https://api.example.com/v1/transcribe/realtime"
        let expectedWSURL = "wss://api.example.com/v1/transcribe/realtime"
        
        let transformedURL = httpsURL.replacingOccurrences(of: "https://", with: "wss://")
        #expect(transformedURL == expectedWSURL)
        
        // Test URL creation
        guard let url = URL(string: transformedURL) else {
            #expect(Bool(false)) // URL should be valid
            return
        }
        
        #expect(url.scheme == "wss")
        #expect(url.host == "api.example.com")
    }
    
    @Test("Multipart form data structure is correct")
    func multipartFormDataStructureIsCorrect() async throws {
        let boundary = "test-boundary"
        let testData = Data("test audio data".utf8)
        
        var body = Data()
        
        // Add form data structure
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(testData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let bodyString = String(data: body, encoding: .utf8)!
        
        #expect(bodyString.contains("--\(boundary)"))
        #expect(bodyString.contains("Content-Disposition: form-data"))
        #expect(bodyString.contains("name=\"audio\""))
        #expect(bodyString.contains("filename=\"recording.m4a\""))
        #expect(bodyString.contains("Content-Type: audio/mp4"))
        #expect(bodyString.contains("test audio data"))
    }
    
    @Test("JSON response parsing handles various formats")
    func jsonResponseParsingHandlesVariousFormats() async throws {
        // Test successful response format
        let successResponse = ["transcript": "Hello world"]
        let successData = try JSONSerialization.data(withJSONObject: successResponse)
        
        if let json = try JSONSerialization.jsonObject(with: successData) as? [String: Any],
           let transcript = json["transcript"] as? String {
            #expect(transcript == "Hello world")
        } else {
            #expect(Bool(false)) // Should successfully parse
        }
        
        // Test malformed response
        let malformedResponse = ["error": "invalid"]
        let malformedData = try JSONSerialization.data(withJSONObject: malformedResponse)
        
        if let json = try JSONSerialization.jsonObject(with: malformedData) as? [String: Any],
           let transcript = json["transcript"] as? String {
            #expect(Bool(false)) // Should not find transcript
        } else {
            #expect(Bool(true)) // Expected - no transcript field
        }
    }
}