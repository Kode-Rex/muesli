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

    @Test("dateRangeString uses explicit conference dates when present")
    @MainActor
    func dateRangeFromExplicitDates() async throws {
        let conf = Conference(
            name: "X",
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            endDate: Date(timeIntervalSince1970: 1_750_500_000)
        )
        let s = ConferenceDetailView.dateRangeString(conference: conf)
        #expect(s != nil)
        #expect(!(s ?? "").isEmpty)
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
