//
//  APIConfiguration.swift
//  Muesli
//
//  Build-time API configuration for different environments
//

import Foundation

struct APIConfiguration {
    
    // MARK: - Build-time Configuration
    
    static let transcriptionAPIBaseURL: String = {
        #if DEBUG
        // Development: Check localhost first, fallback to staging
        return "http://localhost:3000/api/v1"
        #elseif STAGING
        // Staging environment
        return "https://staging-api.muesli-app.com/api/v1" 
        #else
        // Production environment
        return "https://api.muesli-app.com/api/v1"
        #endif
    }()
    
    static let fallbackAPIBaseURL: String = {
        #if DEBUG
        // If localhost fails in debug, fallback to staging
        return "https://staging-api.muesli-app.com/api/v1"
        #else
        // Production fallback (could be secondary server)
        return "https://api-backup.muesli-app.com/api/v1"
        #endif
    }()
    
    // MARK: - Environment Info
    
    static let environmentName: String = {
        #if DEBUG
        return "Development"
        #elseif STAGING  
        return "Staging"
        #else
        return "Production"
        #endif
    }()
    
    static let isDevelopment: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Localhost Detection
    
    static func checkLocalhostAvailability() async -> Bool {
        guard isDevelopment else { return false }
        guard let url = URL(string: "http://localhost:3000/health") else { return false }
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 2.0)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.shared.debug("Localhost health check: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
        } catch {
            AppLogger.shared.debug("Localhost unavailable: \(error.localizedDescription)")
        }
        
        return false
    }
    
    static func getCurrentAPIURL() async -> String {
        // In development, check if localhost is available
        if isDevelopment {
            let localhostAvailable = await checkLocalhostAvailability()
            if localhostAvailable {
                AppLogger.shared.info("Using localhost API: \(transcriptionAPIBaseURL)")
                return transcriptionAPIBaseURL
            } else {
                AppLogger.shared.info("Localhost unavailable, using fallback: \(fallbackAPIBaseURL)")
                return fallbackAPIBaseURL
            }
        }
        
        // For staging/production, always use primary URL
        AppLogger.shared.info("Using \(environmentName) API: \(transcriptionAPIBaseURL)")
        return transcriptionAPIBaseURL
    }
}