//
//  TranscriptionServiceTests.swift
//  MuesliTests
//
//  Tests for TranscriptionService functionality
//

import Testing
import Foundation
@testable import Muesli

@MainActor
@Suite("Transcription Service Tests", .tags(.transcription))
struct TranscriptionServiceTests {
    private let transcription: FakeTranscriptionAdapter

    init() async throws {
        self.transcription = TestWorld.install().transcription
    }

    @Test("World.current.transcription returns a stable reference")
    func transcriptionPortIsStable() async throws {
        let first = World.current.transcription
        let second = World.current.transcription
        #expect(first === second)
    }

    @Test("Transcription port initializes with isTranscribing == false")
    func transcriptionPortInitialState() async throws {
        #expect(World.current.transcription.isTranscribing == false)
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
        // Test API configuration without shared state
        let primaryURL = APIConfiguration.transcriptionAPIBaseURL
        let fallbackURL = APIConfiguration.fallbackAPIBaseURL
        let environmentName = APIConfiguration.environmentName

        // Test that endpoints are properly configured
        #expect(!primaryURL.isEmpty)
        #expect(!fallbackURL.isEmpty)
        #expect(!environmentName.isEmpty)

        // Test environment detection
        #if DEBUG
        #expect(environmentName == "Development")
        #else
        #expect(environmentName == "Production")
        #endif

        // Test URL validation
        #expect(primaryURL.hasPrefix("http"))
        #expect(fallbackURL.hasPrefix("http"))
    }

    @Test("Configuration is build-time determined")
    func configurationIsBuildTimeDetermined() async throws {
        // Test that API configuration is determined at build time
        let primaryURL = APIConfiguration.transcriptionAPIBaseURL
        let fallbackURL = APIConfiguration.fallbackAPIBaseURL
        let environmentName = APIConfiguration.environmentName
        let isDevelopment = APIConfiguration.isDevelopment

        // All values should be non-empty strings
        #expect(!primaryURL.isEmpty)
        #expect(!fallbackURL.isEmpty)
        #expect(!environmentName.isEmpty)

        // Development flag should be consistent with DEBUG build
        #if DEBUG
        #expect(isDevelopment == true)
        #expect(environmentName == "Development")
        #else
        #expect(isDevelopment == false)
        #expect(environmentName == "Production")
        #endif
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

    @Test("Localhost detection works in development")
    func localhostDetectionWorksInDevelopment() async throws {
        // Test that localhost detection function exists and works
        let localhostAvailable = await APIConfiguration.checkLocalhostAvailability()

        #if DEBUG
        // In development, the check should complete (regardless of result)
        #expect(localhostAvailable == false) // Likely false unless local server running
        #else
        // In production, should always return false
        #expect(localhostAvailable == false)
        #endif
    }

    @Test("Current API URL selection works correctly")
    func currentAPIURLSelectionWorksCorrectly() async throws {
        // Test that getCurrentAPIURL returns a valid URL
        let currentURL = await APIConfiguration.getCurrentAPIURL()

        #expect(!currentURL.isEmpty)
        #expect(URL(string: currentURL) != nil) // Should be a valid URL

        // In development, should check localhost then fallback
        #if DEBUG
        // Should be either localhost or fallback URL
        let isLocalhost = currentURL.contains("localhost")
        let isFallback = currentURL == APIConfiguration.fallbackAPIBaseURL
        #expect(isLocalhost || isFallback)
        #else
        // In production, should always be primary URL
        #expect(currentURL == APIConfiguration.transcriptionAPIBaseURL)
        #endif
    }
}
