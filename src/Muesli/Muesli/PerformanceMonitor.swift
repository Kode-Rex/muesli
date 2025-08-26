//
//  PerformanceMonitor.swift
//  Muesli
//
//  Performance monitoring for data operations and UI responsiveness
//

import Foundation
import SwiftUI
import Combine

/// Performance monitoring service for tracking app performance metrics
final class PerformanceMonitor: ObservableObject {
    
    static let shared = PerformanceMonitor()
    
    @Published private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var operationTimers: [String: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startMemoryMonitoring()
    }
    
    // MARK: - Performance Timing
    
    /// Start timing a performance-critical operation
    func startTiming(operation: String) {
        operationTimers[operation] = Date()
        AppLogger.shared.performanceStart(operation)
    }
    
    /// End timing and log the performance metric
    func endTiming(operation: String, recordMetric: Bool = true) -> TimeInterval? {
        guard let startTime = operationTimers.removeValue(forKey: operation) else {
            AppLogger.shared.warning("No start time found for operation: \(operation)")
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        AppLogger.shared.performanceEnd(operation, startTime: startTime)
        
        if recordMetric {
            recordOperationMetric(operation: operation, duration: duration)
        }
        
        return duration
    }
    
    /// Execute a closure and measure its performance
    @discardableResult
    func measure<T>(operation: String, _ closure: () throws -> T) rethrows -> T {
        startTiming(operation: operation)
        defer { endTiming(operation: operation) }
        return try closure()
    }
    
    /// Execute an async closure and measure its performance
    @discardableResult
    func measureAsync<T>(operation: String, _ closure: () async throws -> T) async rethrows -> T {
        startTiming(operation: operation)
        defer { endTiming(operation: operation) }
        return try await closure()
    }
    
    // MARK: - Metrics Recording
    
    private func recordOperationMetric(operation: String, duration: TimeInterval) {
        DispatchQueue.main.async {
            var newMetrics = self.metrics
            
            switch operation {
            case let op where op.contains("Fetch"):
                newMetrics.dataOperations.append(
                    DataOperationMetric(operation: operation, duration: duration, timestamp: Date())
                )
            case let op where op.contains("Search"):
                newMetrics.searchOperations.append(
                    SearchOperationMetric(query: operation, duration: duration, timestamp: Date())
                )
            case let op where op.contains("Save"), let op where op.contains("Create"), let op where op.contains("Update"), let op where op.contains("Delete"):
                newMetrics.writeOperations.append(
                    WriteOperationMetric(operation: operation, duration: duration, timestamp: Date())
                )
            default:
                newMetrics.generalOperations.append(
                    GeneralOperationMetric(operation: operation, duration: duration, timestamp: Date())
                )
            }
            
            // Keep only recent metrics (last 100 operations per type)
            newMetrics.cleanup()
            self.metrics = newMetrics
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recordMemoryUsage()
            }
            .store(in: &cancellables)
    }
    
    func updateMemoryUsage() {
        recordMemoryUsage()
    }
    
    private func recordMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        DispatchQueue.main.async {
            var newMetrics = self.metrics
            newMetrics.memoryUsage.append(
                MemoryUsageMetric(usageMB: memoryUsage, timestamp: Date())
            )
            newMetrics.cleanup()
            self.metrics = newMetrics
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0
        }
    }
    
    // MARK: - Performance Reports
    
    func generatePerformanceReport() -> String {
        let dataOpsAvg = metrics.dataOperations.isEmpty ? 0 : 
            metrics.dataOperations.map(\.duration).reduce(0, +) / Double(metrics.dataOperations.count)
        
        let searchOpsAvg = metrics.searchOperations.isEmpty ? 0 :
            metrics.searchOperations.map(\.duration).reduce(0, +) / Double(metrics.searchOperations.count)
        
        let writeOpsAvg = metrics.writeOperations.isEmpty ? 0 :
            metrics.writeOperations.map(\.duration).reduce(0, +) / Double(metrics.writeOperations.count)
        
        let currentMemory = metrics.memoryUsage.last?.usageMB ?? 0
        let avgMemory = metrics.memoryUsage.isEmpty ? 0 :
            metrics.memoryUsage.map(\.usageMB).reduce(0, +) / Double(metrics.memoryUsage.count)
        
        return """
        📊 Performance Report
        
        Data Operations:
        • Count: \(metrics.dataOperations.count)
        • Average Duration: \(String(format: "%.2f", dataOpsAvg * 1000))ms
        
        Search Operations:
        • Count: \(metrics.searchOperations.count)
        • Average Duration: \(String(format: "%.2f", searchOpsAvg * 1000))ms
        
        Write Operations:
        • Count: \(metrics.writeOperations.count)
        • Average Duration: \(String(format: "%.2f", writeOpsAvg * 1000))ms
        
        Memory Usage:
        • Current: \(String(format: "%.1f", currentMemory))MB
        • Average: \(String(format: "%.1f", avgMemory))MB
        """
    }
}

// MARK: - Performance Metrics Models

struct PerformanceMetrics {
    var dataOperations: [DataOperationMetric] = []
    var searchOperations: [SearchOperationMetric] = []
    var writeOperations: [WriteOperationMetric] = []
    var generalOperations: [GeneralOperationMetric] = []
    var memoryUsage: [MemoryUsageMetric] = []
    
    mutating func cleanup() {
        // Keep only the last 100 entries for each type
        if dataOperations.count > 100 {
            dataOperations = Array(dataOperations.suffix(100))
        }
        if searchOperations.count > 100 {
            searchOperations = Array(searchOperations.suffix(100))
        }
        if writeOperations.count > 100 {
            writeOperations = Array(writeOperations.suffix(100))
        }
        if generalOperations.count > 100 {
            generalOperations = Array(generalOperations.suffix(100))
        }
        if memoryUsage.count > 100 {
            memoryUsage = Array(memoryUsage.suffix(100))
        }
    }
}

struct DataOperationMetric {
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
}

struct SearchOperationMetric {
    let query: String
    let duration: TimeInterval
    let timestamp: Date
}

struct WriteOperationMetric {
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
}

struct GeneralOperationMetric {
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
}

struct MemoryUsageMetric {
    let usageMB: Double
    let timestamp: Date
}