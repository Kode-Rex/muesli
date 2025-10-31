//
//  AISummaryService.swift
//  Muesli
//
//  Created by Kiro on 9/8/25.
//

import Foundation

enum AISummaryError: Error, LocalizedError {
    case apiEndpointNotConfigured
    case networkError
    case invalidResponse
    case serviceUnavailable
    case textTooShort
    
    var errorDescription: String? {
        switch self {
        case .apiEndpointNotConfigured:
            return "AI summary API endpoint not configured"
        case .networkError:
            return "Network error during summarization"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .serviceUnavailable:
            return "AI summary service unavailable"
        case .textTooShort:
            return "Text too short to summarize"
        }
    }
}

struct SummaryResult {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
    let confidence: Double
}

struct SummaryRequest: Codable {
    let text: String
    let type: String // "meeting", "session", "note"
    let options: SummaryOptions
}

struct SummaryOptions: Codable {
    let includeKeyPoints: Bool
    let includeActionItems: Bool
    let maxSummaryLength: Int
    let language: String
    
    init(includeKeyPoints: Bool = true, includeActionItems: Bool = true, maxSummaryLength: Int = 500, language: String = "en") {
        self.includeKeyPoints = includeKeyPoints
        self.includeActionItems = includeActionItems
        self.maxSummaryLength = maxSummaryLength
        self.language = language
    }
}

struct SummaryResponse: Codable {
    let summary: String
    let keyPoints: [String]?
    let actionItems: [String]?
    let confidence: Double?
    let processingTime: Double?
}

@Observable
class AISummaryService {
    
    static let shared = AISummaryService()
    
    private var urlSession: URLSession
    private var currentAPIBaseURL: String = ""
    
    // Published properties
    private(set) var isProcessing: Bool = false
    private(set) var hasValidAPIEndpoint: Bool = false
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // Longer timeout for AI processing
        config.timeoutIntervalForResource = 120
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
    
    // MARK: - Summary Generation
    
    func generateSummary(
        text: String,
        sessionType: String = "note",
        options: SummaryOptions = SummaryOptions()
    ) async throws -> SummaryResult {
        
        // Validate input
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 50 else {
            throw AISummaryError.textTooShort
        }
        
        guard hasValidAPIEndpoint else {
            throw AISummaryError.apiEndpointNotConfigured
        }
        
        guard NetworkMonitor.shared.isConnected else {
            throw AISummaryError.networkError
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        guard let summaryURL = URL(string: "\(currentAPIBaseURL)/summarize") else {
            throw AISummaryError.apiEndpointNotConfigured
        }
        
        var request = URLRequest(url: summaryURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let summaryRequest = SummaryRequest(
            text: text,
            type: sessionType,
            options: options
        )
        
        do {
            let requestData = try JSONEncoder().encode(summaryRequest)
            request.httpBody = requestData
            
            AppLogger.shared.info("Sending text for AI summarization: \(text.count) characters")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AISummaryError.networkError
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                AppLogger.shared.warning("AI summary API returned status: \(httpResponse.statusCode)")
                throw AISummaryError.serviceUnavailable
            }
            
            let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: data)
            
            let result = SummaryResult(
                summary: summaryResponse.summary,
                keyPoints: summaryResponse.keyPoints ?? [],
                actionItems: summaryResponse.actionItems ?? [],
                confidence: summaryResponse.confidence ?? 0.8
            )
            
            AppLogger.shared.info("AI summary generated successfully: \(result.summary.count) characters")
            return result
            
        } catch let decodingError as DecodingError {
            AppLogger.shared.error("Failed to decode AI summary response", error: decodingError)
            throw AISummaryError.invalidResponse
        } catch {
            AppLogger.shared.error("AI summary request failed", error: error)
            throw AISummaryError.networkError
        }
    }
    
    // MARK: - Convenience Methods
    
    func extractActionItems(text: String) async throws -> [String] {
        let options = SummaryOptions(
            includeKeyPoints: false,
            includeActionItems: true,
            maxSummaryLength: 200
        )
        
        let result = try await generateSummary(text: text, options: options)
        return result.actionItems
    }
    
    func generateQuickSummary(text: String, maxLength: Int = 200) async throws -> String {
        let options = SummaryOptions(
            includeKeyPoints: false,
            includeActionItems: false,
            maxSummaryLength: maxLength
        )
        
        let result = try await generateSummary(text: text, options: options)
        return result.summary
    }
    
    // MARK: - Utility Methods
    
    func isConfigured() -> Bool {
        return hasValidAPIEndpoint && NetworkMonitor.shared.isConnected
    }
    
    var currentAPIEndpoint: String {
        return currentAPIBaseURL
    }
}