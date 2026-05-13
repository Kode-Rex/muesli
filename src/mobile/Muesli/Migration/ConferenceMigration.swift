//
//  ConferenceMigration.swift
//  Muesli
//
//  One-time migration that backfills Conference records by grouping
//  existing Notes on their legacy `conferenceName` string. Idempotent:
//  guarded by a UserDefaults flag, and reuses any pre-existing Conference
//  with a matching normalized name.
//

import Foundation
import SwiftData

enum ConferenceMigration {
    static let runFlagKey = "muesli.conferenceMigration.v1.complete"

    /// Groups notes by `conferenceName` (case-insensitive, whitespace-trimmed)
    /// and attaches them to a find-or-created `Conference`. Backfills the
    /// conference's startDate/endDate from the min/max note timestamps.
    /// Idempotent: safe to call multiple times.
    static func run(in context: ModelContext) {
        let unattached = (try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.conference == nil && $0.conferenceName != nil })
        )) ?? []

        var groups: [String: (display: String, notes: [Note])] = [:]
        for note in unattached {
            guard let raw = note.conferenceName else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if groups[key] == nil {
                groups[key] = (display: trimmed, notes: [])
            }
            groups[key]?.notes.append(note)
        }

        let existing = (try? context.fetch(FetchDescriptor<Conference>())) ?? []
        var byKey: [String: Conference] = [:]
        for conf in existing {
            let key = conf.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            byKey[key] = conf
        }

        for (key, group) in groups {
            let conf: Conference
            if let found = byKey[key] {
                conf = found
            } else {
                conf = Conference(name: group.display)
                context.insert(conf)
                byKey[key] = conf
            }

            // group.notes is filtered to `conference == nil`, so no overlap with conf.notes.
            for note in group.notes {
                note.conference = conf
            }
            let timestamps = (conf.notes + group.notes).map(\.timestamp)
            conf.startDate = timestamps.min() ?? conf.startDate
            conf.endDate = timestamps.max() ?? conf.endDate
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: runFlagKey)
        } catch {
            AppLogger.shared.error("ConferenceMigration save failed; will retry on next launch", error: error)
        }
    }

    static var hasRun: Bool {
        UserDefaults.standard.bool(forKey: runFlagKey)
    }
}
