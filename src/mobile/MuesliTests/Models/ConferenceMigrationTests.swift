//
//  ConferenceMigrationTests.swift
//  MuesliTests
//
//  Tests the one-time backfill from Note.conferenceName strings into
//  Conference records with attached note relationships.
//

import XCTest
import SwiftData
@testable import Muesli

@MainActor
final class ConferenceMigrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ConferenceMigration.runFlagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ConferenceMigration.runFlagKey)
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testGroupsNotesByConferenceName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let n1 = Note(title: "Talk A", timestamp: Date(timeIntervalSince1970: 1_000), conferenceName: "DataSummit 2026")
        let n2 = Note(title: "Talk B", timestamp: Date(timeIntervalSince1970: 2_000), conferenceName: "DataSummit 2026")
        let n3 = Note(title: "Solo", timestamp: Date(timeIntervalSince1970: 3_000), conferenceName: "DevWorld")
        let n4 = Note(title: "Loose", timestamp: Date(timeIntervalSince1970: 4_000), conferenceName: nil)
        [n1, n2, n3, n4].forEach { context.insert($0) }
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 2)

        let summit = confs.first { $0.name == "DataSummit 2026" }
        XCTAssertNotNil(summit)
        XCTAssertEqual(summit?.notes.count, 2)
        XCTAssertEqual(summit?.startDate, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(summit?.endDate, Date(timeIntervalSince1970: 2_000))

        let dev = confs.first { $0.name == "DevWorld" }
        XCTAssertEqual(dev?.notes.count, 1)

        XCTAssertNil(n4.conference)
    }

    func testIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let n1 = Note(title: "A", timestamp: Date(timeIntervalSince1970: 1_000), conferenceName: "DataSummit 2026")
        context.insert(n1)
        try context.save()

        ConferenceMigration.run(in: context)
        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Running migration twice must not create duplicates")
        XCTAssertEqual(confs.first?.notes.count, 1)
    }

    func testCaseInsensitiveAndTrimmedGrouping() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let a = Note(title: "A", conferenceName: "DataSummit 2026")
        let b = Note(title: "B", conferenceName: "datasummit 2026")
        let c = Note(title: "C", conferenceName: "  DataSummit 2026  ")
        [a, b, c].forEach { context.insert($0) }
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Names differing only by case or whitespace must group")
        XCTAssertEqual(confs.first?.notes.count, 3)
    }

    func testSkipsNotesAlreadyAttached() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Conference(name: "DataSummit 2026")
        let n = Note(title: "Pre-attached", conferenceName: "DataSummit 2026")
        n.conference = existing
        context.insert(existing)
        context.insert(n)
        try context.save()

        ConferenceMigration.run(in: context)

        let confs = try context.fetch(FetchDescriptor<Conference>())
        XCTAssertEqual(confs.count, 1, "Existing Conference must be reused, not duplicated")
        XCTAssertEqual(confs.first?.notes.count, 1)
    }

    func testHasRunFlagSet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        XCTAssertFalse(ConferenceMigration.hasRun)
        ConferenceMigration.run(in: context)
        XCTAssertTrue(ConferenceMigration.hasRun)
    }
}
