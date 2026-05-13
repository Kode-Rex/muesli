//
//  ConferenceModelTests.swift
//  MuesliTests
//
//  Unit tests for the Conference SwiftData entity.
//

import Testing
import SwiftData
import Foundation
@testable import Muesli

@Suite("Conference Model Tests", .tags(.unit))
struct ConferenceModelTests {
    @Test("Conference initialization with required fields")
    func conferenceInitialization() async throws {
        let conf = Conference(name: "DataSummit 2026")

        #expect(conf.name == "DataSummit 2026")
        #expect(conf.location == nil)
        #expect(conf.startDate == nil)
        #expect(conf.endDate == nil)
        #expect(conf.conferenceDescription == nil)
        #expect(conf.notes.isEmpty)
        #expect(conf.createdAt.timeIntervalSinceNow < 1)
    }

    @Test("Conference initialization with all metadata")
    func conferenceFullInit() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_200_000)
        let conf = Conference(
            name: "DataSummit 2026",
            location: "San Francisco",
            startDate: start,
            endDate: end,
            conferenceDescription: "Annual data conference"
        )

        #expect(conf.location == "San Francisco")
        #expect(conf.startDate == start)
        #expect(conf.endDate == end)
        #expect(conf.conferenceDescription == "Annual data conference")
    }

    @Test("Conference has stable UUID")
    func conferenceStableID() async throws {
        let id = UUID()
        let conf = Conference(id: id, name: "X")
        #expect(conf.id == id)
    }
}
