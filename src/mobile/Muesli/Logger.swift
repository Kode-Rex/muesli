//
//  Logger.swift
//  Muesli
//
//  Enhanced logging system for better debugging and monitoring
//

import Foundation
import os.log

/// Centralized logging service for the Muesli app
final class AppLogger {
    static let shared = AppLogger()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.muesli.app", category: "general")
    private let dataLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.muesli.app", category: "data")
    private let uiLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.muesli.app", category: "ui")
    private let performanceLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.muesli.app", category: "performance")

    private init() {}

    // MARK: - General Logging

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    func info(_ message: String) {
        logger.info("\(message)")
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.warning("[\(fileName):\(line)] \(function) - \(message)")
    }

    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let errorDetail = error?.localizedDescription ?? "No error details"
        logger.error("[\(fileName):\(line)] \(function) - \(message). Error: \(errorDetail)")
    }

    // MARK: - Data Operations Logging

    func dataOperation(_ operation: String, details: String = "") {
        dataLogger.info("Data Operation: \(operation) - \(details)")
    }

    func dataError(_ operation: String, error: Error, details: String = "") {
        dataLogger.error("Data Error in \(operation): \(error.localizedDescription) - \(details)")
    }

    func dataSuccess(_ operation: String, details: String = "") {
        dataLogger.info("✅ Data Success: \(operation) - \(details)")
    }

    // MARK: - UI Logging

    func uiEvent(_ event: String, details: String = "") {
        #if DEBUG
        uiLogger.debug("UI Event: \(event) - \(details)")
        #endif
    }

    func userAction(_ action: String, context: String = "") {
        uiLogger.info("User Action: \(action) - \(context)")
    }

    // MARK: - Performance Logging

    func performance(_ operation: String, duration: TimeInterval, details: String = "") {
        let formattedDuration = String(format: "%.3f", duration * 1_000) // Convert to milliseconds
        performanceLogger.info("⚡ Performance: \(operation) - \(formattedDuration)ms - \(details)")
    }

    func performanceStart(_ operation: String) -> Date {
        performanceLogger.debug("⏱️ Performance Start: \(operation)")
        return Date()
    }

    func performanceEnd(_ operation: String, startTime: Date, details: String = "") {
        let duration = Date().timeIntervalSince(startTime)
        performance(operation, duration: duration, details: details)
    }
}

// MARK: - Convenience Extensions

extension AppLogger {
    /// Log note operations with structured data
    func noteOperation(_ operation: NoteOperation, noteId: String? = nil, title: String? = nil) {
        let noteInfo = [
            noteId.map { "ID: \($0)" },
            title.map { "Title: \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")

        dataOperation(operation.rawValue, details: noteInfo)
    }

    /// Log search operations
    func searchOperation(query: String, resultCount: Int, includeArchived: Bool = false) {
        let context = includeArchived ? "including archived" : "active only"
        dataOperation("Search", details: "Query: '\(query)', Results: \(resultCount) (\(context))")
    }

    /// Log app lifecycle events
    func appLifecycle(_ event: AppLifecycleEvent) {
        info("App Lifecycle: \(event.rawValue)")
    }

    /// Log view lifecycle events
    func viewLifecycle(_ view: String, event: ViewLifecycleEvent) {
        uiEvent("\(view) - \(event.rawValue)")
    }
}

// MARK: - Supporting Enums

enum NoteOperation: String, CaseIterable {
    case create = "Create Note"
    case update = "Update Note"
    case delete = "Delete Note"
    case archive = "Archive Note"
    case unarchive = "Unarchive Note"
    case fetch = "Fetch Notes"
    case search = "Search Notes"
}

enum AppLifecycleEvent: String {
    case launch = "App Launch"
    case background = "App Background"
    case foreground = "App Foreground"
    case terminate = "App Terminate"
}

enum ViewLifecycleEvent: String {
    case appear = "View Appear"
    case disappear = "View Disappear"
    case load = "View Load"
}
