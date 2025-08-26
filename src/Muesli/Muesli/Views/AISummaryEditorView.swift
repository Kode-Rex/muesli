//
//  AISummaryEditorView.swift
//  Muesli
//
//  AI-powered summary editor for notes
//

import SwiftUI

struct AISummaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    @State private var summary = ""
    @State private var isGenerating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.teal)
                            .font(.title2)
                        
                        Text("AI Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    Text("Edit or generate an AI-powered summary for '\(note.title)'")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Summary Editor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                        }
                    }
                    
                    TextEditor(text: $summary)
                        .font(.body)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: generateSummary) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                            Text(isGenerating ? "Generating..." : "Generate AI Summary")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isGenerating ? Color.gray : Color.teal)
                        .cornerRadius(12)
                    }
                    .disabled(isGenerating)
                    
                    Button(action: generateKeyPoints) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16))
                            Text("Extract Key Points")
                        }
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.teal.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .disabled(isGenerating)
                }
                .padding(.horizontal, 20)
                
                // Original Content Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Content")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ScrollView {
                        Text(note.content.isEmpty ? "No content available" : note.content)
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.black)
            .navigationTitle("AI Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSummary()
                    }
                    .foregroundColor(.teal)
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadExistingSummary()
            AppLogger.shared.userAction("Open AI Summary Editor", context: note.title)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingSummary() {
        // For now, check if there's existing summary content
        // This could be stored as metadata or in a separate field
        summary = extractExistingSummary()
    }
    
    private func extractExistingSummary() -> String {
        // Look for existing summary markers in the content
        let lines = note.content.components(separatedBy: .newlines)
        var summaryLines: [String] = []
        var inSummarySection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("summary") || trimmed.lowercased().contains("tldr") {
                inSummarySection = true
                continue
            } else if trimmed.hasPrefix("#") && inSummarySection {
                break
            } else if inSummarySection && !trimmed.isEmpty {
                summaryLines.append(trimmed)
            }
        }
        
        return summaryLines.joined(separator: "\n")
    }
    
    private func generateSummary() {
        guard !note.content.isEmpty else {
            showError("Cannot generate summary for empty note")
            return
        }
        
        isGenerating = true
        AppLogger.shared.userAction("Generate AI Summary", context: note.title)
        
        // Simulate AI processing with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.summary = self.generateSimulatedSummary()
            self.isGenerating = false
        }
    }
    
    private func generateKeyPoints() {
        guard !note.content.isEmpty else {
            showError("Cannot extract key points from empty note")
            return
        }
        
        isGenerating = true
        AppLogger.shared.userAction("Extract Key Points", context: note.title)
        
        // Simulate AI processing with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.summary = self.extractSimulatedKeyPoints()
            self.isGenerating = false
        }
    }
    
    private func generateSimulatedSummary() -> String {
        // Simulate AI-generated summary based on content analysis
        let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines).count
        let hasHeaders = note.content.contains("#")
        let hasBullets = note.content.contains("•") || note.content.contains("○")
        
        var summaryParts: [String] = []
        
        summaryParts.append("📝 **Summary of '\(note.title)'**")
        
        if wordCount > 100 {
            summaryParts.append("This comprehensive note contains \(wordCount) words covering multiple topics.")
        } else {
            summaryParts.append("This concise note covers key information in \(wordCount) words.")
        }
        
        if hasHeaders {
            summaryParts.append("The content is well-organized with clear section headers.")
        }
        
        if hasBullets {
            summaryParts.append("Key points are structured using bullet points for easy reference.")
        }
        
        // Add session-specific insights
        switch note.sessionType {
        case "meeting":
            summaryParts.append("**Meeting Insights:** Action items and decisions are clearly outlined.")
        case "session":
            summaryParts.append("**Session Insights:** Important concepts and takeaways are documented.")
        default:
            summaryParts.append("**Key Insights:** Essential information is captured for future reference.")
        }
        
        summaryParts.append("**Generated on:** \(Date().formatted(date: .abbreviated, time: .shortened))")
        
        return summaryParts.joined(separator: "\n\n")
    }
    
    private func extractSimulatedKeyPoints() -> String {
        let lines = note.content.components(separatedBy: .newlines)
        var keyPoints: [String] = []
        
        // Extract headers and bullet points as key points
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                keyPoints.append("🎯 " + String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("• ") {
                keyPoints.append("• " + String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("○ ") {
                keyPoints.append("  ○ " + String(trimmed.dropFirst(2)))
            }
        }
        
        if keyPoints.isEmpty {
            // Generate generic key points if no structure found
            keyPoints = [
                "📝 Content captured from '\(note.title)'",
                "• Session type: \(note.sessionType.capitalized)",
                "• Created: \(note.dateString)",
                "• Word count: ~\(note.content.components(separatedBy: .whitespacesAndNewlines).count) words"
            ]
        }
        
        return "**Key Points:**\n\n" + keyPoints.joined(separator: "\n")
    }
    
    private func saveSummary() {
        do {
            // For now, we'll prepend the summary to the note content
            let summarySection = "# AI Summary\n\n\(summary)\n\n---\n\n"
            
            // Remove existing summary if present
            var cleanContent = note.content
            if cleanContent.contains("# AI Summary") {
                let components = cleanContent.components(separatedBy: "---")
                if components.count > 1 {
                    cleanContent = components.dropFirst().joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            note.content = summarySection + cleanContent
            try modelContext.save()
            
            AppLogger.shared.userAction("Save AI Summary", context: note.title)
            dismiss()
        } catch {
            showError("Failed to save summary: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        AppLogger.shared.error("AI Summary Editor Error: \(message)")
    }
}

#Preview {
    let sampleNote = Note(
        title: "Sample Meeting",
        content: """
        # Meeting Overview
        
        • Discussed project timeline
        • Reviewed budget allocations
        • Assigned team responsibilities
        
        # Action Items
        
        ○ Schedule follow-up meeting
        ○ Prepare status report
        ○ Contact external vendors
        """,
        sessionType: "meeting"
    )
    
    AISummaryEditorView(note: sampleNote)
}