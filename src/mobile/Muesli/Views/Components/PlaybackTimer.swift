//
//  PlaybackTimer.swift
//  Muesli
//
//  Pure helpers used by the chaptered playback view: decode chapters,
//  pick the current chapter for a playback time, and format times.
//

import Foundation

struct ChapterModel: Equatable, Identifiable {
    var id: Int
    var start: Double
    var title: String
    var summary: String

    init(id: Int = 0, start: Double, title: String, summary: String) {
        self.id = id
        self.start = start
        self.title = title
        self.summary = summary
    }
}

enum PlaybackTimer {
    /// Decode chapters from the JSON shape `BlendOrchestrator` persists to
    /// `note.chaptersJSON`. Empty list on missing or malformed input.
    static func decodeChapters(from data: Data?) -> [ChapterModel] {
        guard let data else { return [] }
        guard let wrapper = try? JSONDecoder().decode(ChaptersWrapper.self, from: data) else { return [] }
        return wrapper.chapters.enumerated().map { idx, dto in
            ChapterModel(id: idx, start: dto.start, title: dto.title, summary: dto.summary ?? "")
        }
    }

    /// Returns the index of the chapter whose `start <= time`, picking the last
    /// satisfying. Returns 0 for empty chapter lists or times before the first
    /// chapter starts.
    static func currentChapterIndex(at time: Double, chapters: [ChapterModel]) -> Int {
        guard !chapters.isEmpty else { return 0 }
        var index = 0
        for (i, chapter) in chapters.enumerated() where chapter.start <= time {
            index = i
        }
        return index
    }

    /// mm:ss under one hour, h:mm:ss at one hour and over.
    static func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.toNearestOrEven)))
        let h = total / 3_600
        let m = (total % 3_600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
