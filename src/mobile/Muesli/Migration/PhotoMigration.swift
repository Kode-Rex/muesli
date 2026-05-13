//
//  PhotoMigration.swift
//  Muesli
//
//  One-time migration that converts legacy `Note.imagePaths` string paths
//  into proper `Photo` SwiftData records with SHA-256 content hashes.
//

import Foundation
import SwiftData
import CryptoKit

enum PhotoMigration {
    private static let runFlagKey = "muesli.photoMigration.v1.complete"

    /// Migrate all Notes that still have un-migrated imagePaths entries.
    /// - Parameters:
    ///   - context: The SwiftData ModelContext to read and write into.
    ///   - fileBytesProvider: Closure that receives a file path and returns the file's bytes,
    ///     or `nil` if the file is unavailable. When `nil` is returned the path string itself
    ///     is used as the hash input so migration is still idempotent.
    static func run(in context: ModelContext, fileBytesProvider: (String) -> Data?) {
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        for note in allNotes {
            let existingPaths = Set(note.photos.map(\.localPath))
            for path in note.imagePaths where !existingPaths.contains(path) {
                let bytes = fileBytesProvider(path) ?? Data(path.utf8)
                let hash = SHA256.hash(data: bytes)
                    .compactMap { String(format: "%02x", $0) }
                    .joined()
                let photo = Photo(
                    localPath: path,
                    contentHash: hash,
                    capturedAt: note.timestamp,
                    note: note
                )
                context.insert(photo)
                note.photos.append(photo)
            }
        }
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: runFlagKey)
        } catch {
            AppLogger.shared.error("PhotoMigration save failed; will retry on next launch", error: error)
        }
    }

    static var hasRun: Bool {
        UserDefaults.standard.bool(forKey: runFlagKey)
    }
}
