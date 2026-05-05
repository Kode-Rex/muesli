//
//  Photo.swift
//  Muesli
//
//  SwiftData model for photos captured during a note session.
//

import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var localPath: String
    var contentHash: String
    var capturedAt: Date
    var ocrText: String?
    var photoDescription: String?    // 'description' is reserved on NSObject
    var extractStatusRaw: String     // pending / complete / failed
    var note: Note?

    var extractStatus: ExtractStatus {
        get { ExtractStatus(rawValue: extractStatusRaw) ?? .pending }
        set { extractStatusRaw = newValue.rawValue }
    }

    init(localPath: String, contentHash: String, capturedAt: Date, note: Note? = nil) {
        self.id = UUID()
        self.localPath = localPath
        self.contentHash = contentHash
        self.capturedAt = capturedAt
        self.extractStatusRaw = ExtractStatus.pending.rawValue
        self.note = note
    }
}

enum ExtractStatus: String, Codable {
    case pending, complete, failed
}
