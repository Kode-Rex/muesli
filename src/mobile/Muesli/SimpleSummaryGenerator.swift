//
//  SimpleSummaryGenerator.swift
//  Muesli
//
//  Simple text-based summary generator for transcripts
//

import Foundation

struct SimpleSummaryGenerator {

    /// Generates a short title from transcript (first meaningful phrase or timestamp)
    static func generateTitle(from transcript: String) -> String {
        guard !transcript.isEmpty else {
            return timestampTitle()
        }

        // Extract first sentence or meaningful phrase
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 3 }

        guard let firstSentence = sentences.first else {
            return timestampTitle()
        }

        // Take first 50 characters of first sentence
        let title = String(firstSentence.prefix(50))

        // Add ellipsis if truncated
        if firstSentence.count > 50 {
            return title + "..."
        }

        return title
    }

    /// Generates timestamp-based title: yyyy-MM-dd HH:mm:ss
    static func timestampTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    /// Generates a concise bullet-point summary from a transcript and user notes
    static func generateSummary(from transcript: String, userNotes: String = "") -> String {
        guard !transcript.isEmpty || !userNotes.isEmpty else {
            return "No content to summarize."
        }

        // Split into sentences
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 }

        guard !sentences.isEmpty else {
            return "Recording is too short to summarize."
        }

        // Take key sentences (first, middle, last few)
        var summary = "# Summary\n\n"

        // Add first sentence (usually the topic)
        if let first = sentences.first {
            summary += "• \(first)\n"
        }

        // Add some middle sentences (key points)
        if sentences.count > 3 {
            let middleStart = sentences.count / 3
            let middleEnd = min(middleStart + 2, sentences.count - 1)
            for i in middleStart..<middleEnd {
                summary += "• \(sentences[i])\n"
            }
        }

        // Add last sentence (conclusion/action)
        if sentences.count > 1, let last = sentences.last, last != sentences.first {
            summary += "• \(last)\n"
        }

        // Add word count for transcript
        if !transcript.isEmpty {
            let wordCount = transcript.split(separator: " ").count
            summary += "\n○ \(wordCount) words transcribed"

            if let duration = estimateDuration(wordCount: wordCount) {
                summary += "\n○ ~\(duration) speaking time"
            }
        }

        // Add user notes section if present
        if !userNotes.isEmpty {
            summary += "\n\n# My Notes\n\n"
            let noteLines = userNotes.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for noteLine in noteLines {
                // Add bullet if not already present
                if noteLine.hasPrefix("•") || noteLine.hasPrefix("-") || noteLine.hasPrefix("*") {
                    summary += "\(noteLine)\n"
                } else {
                    summary += "• \(noteLine)\n"
                }
            }
        }

        return summary
    }

    /// Estimates speaking duration based on word count (average ~150 words/minute)
    private static func estimateDuration(wordCount: Int) -> String? {
        guard wordCount > 0 else { return nil }

        let minutes = Double(wordCount) / 150.0

        if minutes < 1 {
            let seconds = Int(minutes * 60)
            return "\(seconds) seconds"
        } else {
            let mins = Int(minutes)
            let secs = Int((minutes - Double(mins)) * 60)
            if secs > 0 {
                return "\(mins)m \(secs)s"
            } else {
                return "\(mins) minute\(mins == 1 ? "" : "s")"
            }
        }
    }
}
