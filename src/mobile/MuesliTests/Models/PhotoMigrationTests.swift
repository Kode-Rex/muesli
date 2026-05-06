//
//  PhotoMigrationTests.swift
//  MuesliTests
//
//  Tests for the one-time Photo migration from Note.imagePaths.
//

import XCTest
import SwiftData
@testable import Muesli

@MainActor
final class PhotoMigrationTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testMigratesImagePathsToPhotos() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let note = Note(title: "Talk", imagePaths: ["a.jpg", "b.jpg", "c.jpg"])
        context.insert(note)
        try context.save()

        // fileBytesProvider returns the path's UTF-8 bytes — produces a unique hash per path.
        PhotoMigration.run(in: context, fileBytesProvider: { path in
            Data(path.utf8)
        })

        XCTAssertEqual(note.photos.count, 3)
        XCTAssertNotEqual(note.photos[0].contentHash, note.photos[1].contentHash)
        // capturedAt defaults to note.timestamp
        XCTAssertEqual(note.photos[0].capturedAt, note.timestamp)
    }

    func testIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let note = Note(title: "Talk", imagePaths: ["x.jpg"])
        context.insert(note)
        try context.save()

        PhotoMigration.run(in: context, fileBytesProvider: { _ in Data([1, 2, 3]) })
        PhotoMigration.run(in: context, fileBytesProvider: { _ in Data([1, 2, 3]) })

        XCTAssertEqual(note.photos.count, 1)
    }
}
