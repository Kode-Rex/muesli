//
//  Models.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

@Model
final class Note {
    var title: String
    var content: String
    var timestamp: Date
    var conferenceName: String?
    var sessionType: String // "meeting", "session", "note"
    var isArchived: Bool
    
    init(
        title: String,
        content: String = "",
        timestamp: Date = Date(),
        conferenceName: String? = nil,
        sessionType: String = "note",
        isArchived: Bool = false
    ) {
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.conferenceName = conferenceName
        self.sessionType = sessionType
        self.isArchived = isArchived
    }
}

// MARK: - Sample Data Types
typealias SampleNote = (title: String, time: String, date: String, isArchived: Bool)
