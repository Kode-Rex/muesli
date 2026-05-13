//
//  MainViewTests.swift
//  MuesliTests
//
//  Logic tests for MainView's conference-grouping helper.
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Main View Tests", .tags(.unit))
struct MainViewTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("partition groups notes by conference relationship and bucks ungrouped into Other")
    @MainActor
    func partitionGroupsByConference() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let summit = Conference(name: "DataSummit 2026")
        let solo = Note(title: "Standup")
        let talk1 = Note(title: "Three pillars", conference: summit)
        let talk2 = Note(title: "Streaming", conference: summit)
        context.insert(summit)
        context.insert(solo)
        context.insert(talk1)
        context.insert(talk2)
        try context.save()

        let groups = MainView.partition(notes: [solo, talk1, talk2])

        #expect(groups.count == 2)
        let summitGroup = groups.first { $0.conference?.id == summit.id }
        #expect(summitGroup?.notes.count == 2)
        let other = groups.first { $0.conference == nil }
        #expect(other?.notes.count == 1)
        #expect(other?.notes.first?.title == "Standup")
    }

    @Test("partition orders conference groups by most-recent note descending")
    @MainActor
    func conferenceGroupsOrderedByRecency() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let older = Conference(name: "Older 2024")
        let newer = Conference(name: "Newer 2026")
        let n1 = Note(title: "Old", timestamp: Date(timeIntervalSinceNow: -1_000_000), conference: older)
        let n2 = Note(title: "Recent", timestamp: Date(timeIntervalSinceNow: -1_000), conference: newer)
        context.insert(older)
        context.insert(newer)
        context.insert(n1)
        context.insert(n2)
        try context.save()

        let groups = MainView.partition(notes: [n1, n2])
        #expect(groups.first?.conference?.id == newer.id)
    }

    @Test("partition returns an empty array for an empty notes list")
    @MainActor
    func partitionEmpty() async throws {
        let groups = MainView.partition(notes: [])
        #expect(groups.isEmpty)
    }
}
