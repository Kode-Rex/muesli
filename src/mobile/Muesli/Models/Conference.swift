//
//  Conference.swift
//  Muesli
//
//  SwiftData entity representing a conference, grouping multiple Note talks.
//

import Foundation
import SwiftData

@Model
final class Conference {
    var id: UUID
    var name: String
    var location: String?
    var startDate: Date?
    var endDate: Date?
    var conferenceDescription: String?    // `description` is reserved on NSObject
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Note.conference)
    var notes: [Note] = []

    init(
        id: UUID = UUID(),
        name: String,
        location: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        conferenceDescription: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.conferenceDescription = conferenceDescription
        self.createdAt = createdAt
    }
}
