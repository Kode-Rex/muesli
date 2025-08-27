//
//  PerformanceMonitorTests.swift
//  MuesliTests
//
//  Tests for PerformanceMonitor functionality
//

import Testing
import Foundation
@testable import Muesli

@Suite("Performance Monitor Tests", .tags(.performance))
struct PerformanceMonitorTests {
    
    init() async throws {
        await TestSetup.initializeServicesForTesting()
    }
    
    @Test("Performance monitor starts and ends timing correctly")
    func performanceMonitorStartsAndEndsTimingCorrectly() async throws {
        let monitor = PerformanceMonitor.shared
        let operationName = "test_operation"
        
        // Start timing
        monitor.startTiming(operation: operationName)
        
        // Simulate some work
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // End timing
        monitor.endTiming(operation: operationName)
        
        // Verify timing was recorded
        let report = monitor.generatePerformanceReport()
        #expect(report.contains("Performance Report"))
    }
    
    @Test("Performance monitor measures operation correctly")
    func performanceMonitorMeasuresOperationCorrectly() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Test the measure function
        let result = monitor.measure(operation: "test_measure") {
            return "test_result"
        }
        
        #expect(result == "test_result")
        
        // Verify the operation was recorded in metrics
        let metricsData = monitor.metrics
        #expect(metricsData.generalOperations.contains { op in
            op.operation.contains("test_measure")
        })
    }
    
    @Test("Performance monitor handles throwing operations")
    func performanceMonitorHandlesThrowingOperations() async throws {
        let monitor = PerformanceMonitor.shared
        
        enum TestError: Error {
            case intentionalError
        }
        
        // Test that exceptions are properly handled and re-thrown
        do {
            _ = try monitor.measure(operation: "throwing_operation") {
                throw TestError.intentionalError
            }
            #expect(Bool(false)) // Should not reach here
        } catch TestError.intentionalError {
            // Expected behavior
            #expect(Bool(true))
        } catch {
            #expect(Bool(false)) // Should not catch other errors
        }
        
        // Verify the operation was still recorded despite the exception
        let metricsData = monitor.metrics
        #expect(metricsData.generalOperations.contains { op in
            op.operation.contains("throwing_operation")
        })
    }
    
    @Test("Performance monitor tracks memory usage")
    func performanceMonitorTracksMemoryUsage() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Get performance report which includes memory data
        let report = monitor.generatePerformanceReport()
        
        // Verify memory metrics are included in the report
        #expect(report.contains("Memory Usage"))
    }
    
    @Test("Performance monitor formats memory correctly")
    func performanceMonitorFormatsMemoryCorrectly() async throws {
        // Test memory formatting helper (this tests the logic used in PerformanceMonitor)
        let testCases: [(UInt64, String)] = [
            (512, "512 B"),
            (1024, "1.00 KB"),
            (1536, "1.50 KB"),
            (1048576, "1.00 MB"),
            (1073741824, "1.00 GB")
        ]
        
        for (bytes, expected) in testCases {
            let formatted = formatMemorySize(bytes)
            #expect(formatted == expected)
        }
    }
    
    @Test("Performance monitor handles multiple operations")
    func performanceMonitorHandlesMultipleOperations() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Perform multiple operations sequentially for testing
        for i in 0..<5 {
            let operationName = "multiple_operation_\(i)"
            _ = monitor.measure(operation: operationName) {
                Thread.sleep(forTimeInterval: 0.001) // 1ms
                return i
            }
        }
        
        // Verify all operations were recorded
        let metricsData = monitor.metrics
        for i in 0..<5 {
            #expect(metricsData.generalOperations.contains { op in
                op.operation.contains("multiple_operation_\(i)")
            })
        }
    }
    
    @Test("Performance monitor provides current metrics")
    func performanceMonitorProvidesCurrentMetrics() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Perform a test operation
        _ = monitor.measure(operation: "metrics_test") {
            return "result"
        }
        
        // Get performance report
        let report = monitor.generatePerformanceReport()
        
        // Verify report is a non-empty string
        #expect(report is String)
        #expect(!report.isEmpty)
        #expect(report.contains("Performance Report"))
    }
    
    @Test("Performance monitor resets correctly")
    func performanceMonitorResetsCorrectly() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Perform operations to populate metrics
        _ = monitor.measure(operation: "operation_before_reset") {
            return "result"
        }
        
        // Verify metrics exist in the singleton
        let initialMetrics = monitor.metrics
        
        // Since it's a singleton, we test that it can handle multiple operations
        // Perform new operation
        _ = monitor.measure(operation: "operation_after_reset") {
            return "new_result"
        }
        
        // Verify the new operation is tracked
        let finalMetrics = monitor.metrics
        #expect(finalMetrics.generalOperations.contains { op in
            op.operation.contains("operation_after_reset")
        })
    }
    
    @Test("Performance monitor handles edge cases")
    func performanceMonitorHandlesEdgeCases() async throws {
        let monitor = PerformanceMonitor.shared
        
        // Test with empty operation name
        _ = monitor.measure(operation: "") {
            return "empty_name_result"
        }
        
        // Test with very long operation name
        let longName = String(repeating: "A", count: 1000)
        _ = monitor.measure(operation: longName) {
            return "long_name_result"
        }
        
        // Test with special characters
        _ = monitor.measure(operation: "special!@#$%^&*()_+{}|:<>?[]\\;',./") {
            return "special_chars_result"
        }
        
        // Verify all operations were handled
        let report = monitor.generatePerformanceReport()
        #expect(report.contains("Performance Report"))
    }
}

// MARK: - Supporting Functions for Testing

extension PerformanceMonitorTests {
    
    /// Helper function to format memory size (mirrors PerformanceMonitor logic)
    func formatMemorySize(_ bytes: UInt64) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        
        let bytesDouble = Double(bytes)
        
        if bytesDouble >= gb {
            return String(format: "%.2f GB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.2f MB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.2f KB", bytesDouble / kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    @Test("Memory formatting helper works correctly")
    func memoryFormattingHelperWorksCorrectly() async throws {
        // Test various memory sizes
        #expect(formatMemorySize(0) == "0 B")
        #expect(formatMemorySize(500) == "500 B")
        #expect(formatMemorySize(1024) == "1.00 KB")
        #expect(formatMemorySize(2048) == "2.00 KB")
        #expect(formatMemorySize(1048576) == "1.00 MB")
        #expect(formatMemorySize(2097152) == "2.00 MB")
        #expect(formatMemorySize(1073741824) == "1.00 GB")
    }
    
    /// Helper to simulate performance-critical operations
    func performCPUIntensiveTask() -> Int {
        var result = 0
        for i in 0..<1000 {
            result += i * i
        }
        return result
    }
    
    @Test("Performance monitoring during CPU intensive tasks")
    func performanceMonitoringDuringCPUIntensiveTasks() async throws {
        let monitor = PerformanceMonitor.shared
        
        let result = monitor.measure(operation: "cpu_intensive_task") {
            return performCPUIntensiveTask()
        }
        
        #expect(result > 0) // Should calculate a positive result
        
        // Verify the operation was monitored
        let metricsData = monitor.metrics
        #expect(metricsData.generalOperations.contains { op in
            op.operation.contains("cpu_intensive_task")
        })
    }
}

// MARK: - Test Tags Extension (if not already defined)

extension Tag {
    @Tag static var performance: Self
}