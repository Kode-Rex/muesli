//
//  SimpleSummaryGeneratorTests.swift
//  MuesliTests
//
//  Unit tests for SimpleSummaryGenerator
//

import XCTest
@testable import Muesli

@MainActor
final class SimpleSummaryGeneratorTests: XCTestCase {

    // MARK: - Title Generation Tests

    func testGenerateTitleFromTranscript() {
        let transcript = "This is a meeting about project planning. We discussed the roadmap and milestones."
        let title = SimpleSummaryGenerator.generateTitle(from: transcript)

        XCTAssertEqual(title, "This is a meeting about project planning")
    }

    func testGenerateTitleFromLongTranscript() {
        let transcript = "This is a very long sentence that exceeds fifty characters and should be truncated with ellipsis at the end."
        let title = SimpleSummaryGenerator.generateTitle(from: transcript)

        XCTAssertTrue(title.hasSuffix("..."))
        XCTAssertLessThanOrEqual(title.count, 53) // 50 chars + "..."
    }

    func testGenerateTitleFromEmptyTranscript() {
        let title = SimpleSummaryGenerator.generateTitle(from: "")

        // Should return timestamp format: yyyy-MM-dd HH:mm:ss
        XCTAssertEqual(title.count, 19)
        XCTAssertTrue(title.contains("-"))
        XCTAssertTrue(title.contains(":"))
    }

    func testTimestampTitleFormat() {
        let title = SimpleSummaryGenerator.timestampTitle()

        // Format: yyyy-MM-dd HH:mm:ss (19 characters)
        XCTAssertEqual(title.count, 19)
        XCTAssertTrue(title.range(of: "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", options: .regularExpression) != nil)
    }

    // MARK: - Summary Generation Tests

    func testGenerateSummaryFromTranscriptOnly() {
        let transcript = "This is the first sentence. Here is the second one. And the third sentence. Finally the last one."
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: "")

        XCTAssertTrue(summary.contains("# Summary"))
        XCTAssertTrue(summary.contains("• This is the first sentence"))
        XCTAssertTrue(summary.contains("words transcribed"))
        XCTAssertFalse(summary.contains("# My Notes"))
    }

    func testGenerateSummaryFromUserNotesOnly() {
        let userNotes = "Remember to follow up\nSchedule next meeting\nReview the budget"
        let summary = SimpleSummaryGenerator.generateSummary(from: "", userNotes: userNotes)

        XCTAssertTrue(summary.contains("# My Notes"))
        XCTAssertTrue(summary.contains("• Remember to follow up"))
        XCTAssertTrue(summary.contains("• Schedule next meeting"))
        XCTAssertTrue(summary.contains("• Review the budget"))
        XCTAssertFalse(summary.contains("# Summary"))
    }

    func testGenerateSummaryFromBothTranscriptAndUserNotes() {
        let transcript = "We discussed the project timeline. The deadline is next month. Everyone agreed to the plan."
        let userNotes = "Action item: Send email\nFollow up with team"
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: userNotes)

        // Should contain both sections
        XCTAssertTrue(summary.contains("# Summary"))
        XCTAssertTrue(summary.contains("# My Notes"))
        XCTAssertTrue(summary.contains("• We discussed the project timeline"))
        XCTAssertTrue(summary.contains("• Action item: Send email"))
        XCTAssertTrue(summary.contains("words transcribed"))
    }

    func testGenerateSummaryWithEmptyInputs() {
        let summary = SimpleSummaryGenerator.generateSummary(from: "", userNotes: "")

        XCTAssertEqual(summary, "No content to summarize.")
    }

    func testGenerateSummaryPreservesBullets() {
        let userNotes = "• Already has bullet\n- Has dash\n* Has asterisk\nNo bullet"
        let summary = SimpleSummaryGenerator.generateSummary(from: "", userNotes: userNotes)

        XCTAssertTrue(summary.contains("• Already has bullet"))
        XCTAssertTrue(summary.contains("- Has dash"))
        XCTAssertTrue(summary.contains("* Has asterisk"))
        XCTAssertTrue(summary.contains("• No bullet"))
    }

    func testGenerateSummaryHandlesMultipleSentences() {
        let transcript = """
        First sentence here. Second sentence about something. Third point to discuss.
        Fourth item on the agenda. Fifth topic was important. Last concluding statement.
        """
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: "")

        // Should include first, some middle, and last sentences
        XCTAssertTrue(summary.contains("• First sentence here"))
        XCTAssertTrue(summary.contains("• Last concluding statement"))
    }

    func testGenerateSummaryIncludesWordCount() {
        let transcript = "One two three four five six seven eight nine ten"
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: "")

        XCTAssertTrue(summary.contains("10 words transcribed"))
    }

    func testGenerateSummaryIncludesDuration() {
        let transcript = String(repeating: "word ", count: 150) // 150 words = ~1 minute
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: "")

        XCTAssertTrue(summary.contains("speaking time"))
    }

    // MARK: - Edge Cases

    func testGenerateSummaryWithWhitespaceOnly() {
        let userNotes = "   \n\n   \n   "
        let summary = SimpleSummaryGenerator.generateSummary(from: "", userNotes: userNotes)

        // Should filter out whitespace-only lines, treating as empty
        XCTAssertTrue(summary.isEmpty || summary == "No content to summarize." || summary.contains("# My Notes"))
    }

    func testGenerateSummaryWithSingleWordTranscript() {
        let transcript = "Hello"
        let summary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: "")

        // Short transcripts might not generate full sentences, but shouldn't crash
        XCTAssertFalse(summary.isEmpty)
        // Should at least have the transcript info or empty sections handled gracefully
    }

    func testGenerateSummaryFiltersEmptyLines() {
        let userNotes = "First line\n\n\nSecond line\n\n"
        let summary = SimpleSummaryGenerator.generateSummary(from: "", userNotes: userNotes)

        // Should only have two bullet points
        let bulletCount = summary.components(separatedBy: "• ").count - 1
        XCTAssertEqual(bulletCount, 2)
    }
}
