//
//  ConferenceDetailViewTests.swift
//  MuesliTests
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Conference Detail View Tests", .tags(.unit))
struct ConferenceDetailViewTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("dateRangeString uses explicit conference dates when present (contains the year)")
    @MainActor
    func dateRangeFromExplicitDates() async throws {
        // 2025-06-15 → 2025-06-21 (same year)
        let conf = Conference(
            name: "X",
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            endDate: Date(timeIntervalSince1970: 1_750_500_000)
        )
        let s = ConferenceDetailView.dateRangeString(conference: conf)
        let str = try #require(s)
        // Same-year range should contain the year exactly once (on the end).
        #expect(str.contains("2025"))
        #expect(str.contains("–"))
    }

    @Test("dateRangeString keeps both years when the range crosses a year boundary")
    @MainActor
    func dateRangeCrossYear() async throws {
        let dec30_2025 = Date(timeIntervalSince1970: 1_767_052_800) // 2025-12-30
        let jan2_2026  = Date(timeIntervalSince1970: 1_767_312_000) // 2026-01-02
        let conf = Conference(name: "X", startDate: dec30_2025, endDate: jan2_2026)
        let s = ConferenceDetailView.dateRangeString(conference: conf)
        let str = try #require(s)
        #expect(str.contains("2025"))
        #expect(str.contains("2026"))
    }

    @Test("dateRangeString returns nil when both dates are nil and no notes attached")
    @MainActor
    func dateRangeNilWhenAbsent() async throws {
        let conf = Conference(name: "X")
        #expect(ConferenceDetailView.dateRangeString(conference: conf) == nil)
    }

    @Test("dateRangeString falls back to note timestamps when conference dates are missing")
    @MainActor
    func dateRangeFromNoteTimestamps() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let conf = Conference(name: "X")
        context.insert(conf)
        let n1 = Note(title: "a", timestamp: Date(timeIntervalSince1970: 1_750_000_000), conference: conf)
        let n2 = Note(title: "b", timestamp: Date(timeIntervalSince1970: 1_750_500_000), conference: conf)
        context.insert(n1)
        context.insert(n2)
        try context.save()

        let s = ConferenceDetailView.dateRangeString(conference: conf)
        #expect(s != nil)
    }

    @Test("dateRangeString collapses to one date when start == end")
    @MainActor
    func dateRangeSingleDay() async throws {
        let day = Date(timeIntervalSince1970: 1_750_000_000)
        let conf = Conference(name: "X", startDate: day, endDate: day)
        let s = ConferenceDetailView.dateRangeString(conference: conf)
        #expect(s != nil)
        #expect(!(s ?? "").contains("–"))
    }
}
