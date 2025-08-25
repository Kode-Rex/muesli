//
//  Item.swift
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
    
    init(title: String, content: String = "", timestamp: Date = Date(), conferenceName: String? = nil, sessionType: String = "note") {
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.conferenceName = conferenceName
        self.sessionType = sessionType
    }
}
