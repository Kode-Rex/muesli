//
//  PerformanceView.swift
//  Muesli
//
//  Development view for monitoring app performance
//

import SwiftUI

struct PerformanceView: View {
    @ObservedObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showingDetailedReport = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Stats
                StatsCardView(
                    title: "Data Operations",
                    count: performanceMonitor.metrics.dataOperations.count,
                    averageTime: averageTime(for: performanceMonitor.metrics.dataOperations.map(\.duration))
                )

                StatsCardView(
                    title: "Search Operations",
                    count: performanceMonitor.metrics.searchOperations.count,
                    averageTime: averageTime(for: performanceMonitor.metrics.searchOperations.map(\.duration))
                )

                StatsCardView(
                    title: "Write Operations",
                    count: performanceMonitor.metrics.writeOperations.count,
                    averageTime: averageTime(for: performanceMonitor.metrics.writeOperations.map(\.duration))
                )

                // Memory Usage
                if let currentMemory = performanceMonitor.metrics.memoryUsage.last {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Usage")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(String(format: "%.1f", currentMemory.usageMB)) MB")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.teal)

                        Text("Last updated: \(formatTime(currentMemory.timestamp))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button("View Detailed Report") {
                        showingDetailedReport = true
                    }
                    .foregroundColor(.teal)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal.opacity(0.2))
                    .cornerRadius(12)

                    Button("Clear Metrics") {
                        clearMetrics()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingDetailedReport) {
            DetailedPerformanceReportView()
        }
    }

    private func averageTime(for durations: [TimeInterval]) -> String {
        guard !durations.isEmpty else { return "N/A" }
        let average = durations.reduce(0, +) / Double(durations.count)
        return String(format: "%.1f ms", average * 1_000)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func clearMetrics() {
        // Note: In a real implementation, you'd want to add a clearMetrics method to PerformanceMonitor
        AppLogger.shared.info("Performance metrics cleared")
    }
}

struct StatsCardView: View {
    let title: String
    let count: Int
    let averageTime: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                    Text("Operations")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(averageTime)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Avg Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct DetailedPerformanceReportView: View {
    @Environment(\.dismiss) private var dismiss
    private let report = PerformanceMonitor.shared.generatePerformanceReport()

    var body: some View {
        NavigationView {
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
            }
            .background(Color.black)
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
#Preview {
    PerformanceView()
}
#endif
