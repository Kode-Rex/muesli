//
//  PlaybackTimerTests.swift
//  MuesliTests
//

import Testing
import Foundation
@testable import Muesli

@Suite("Playback Timer Tests", .tags(.unit))
struct PlaybackTimerTests {
    private func chapters() -> [ChapterModel] {
        [
            ChapterModel(id: 0, start: 0, title: "Intro", summary: ""),
            ChapterModel(id: 1, start: 120, title: "Middle", summary: ""),
            ChapterModel(id: 2, start: 480, title: "Outro", summary: "")
        ]
    }

    @Test("currentChapterIndex returns 0 before second chapter starts")
    func beforeSecond() {
        #expect(PlaybackTimer.currentChapterIndex(at: 0, chapters: chapters()) == 0)
        #expect(PlaybackTimer.currentChapterIndex(at: 60, chapters: chapters()) == 0)
        #expect(PlaybackTimer.currentChapterIndex(at: 119.9, chapters: chapters()) == 0)
    }

    @Test("currentChapterIndex returns the chapter whose start <= time")
    func picksLastSatisfying() {
        #expect(PlaybackTimer.currentChapterIndex(at: 120, chapters: chapters()) == 1)
        #expect(PlaybackTimer.currentChapterIndex(at: 200, chapters: chapters()) == 1)
        #expect(PlaybackTimer.currentChapterIndex(at: 480, chapters: chapters()) == 2)
        #expect(PlaybackTimer.currentChapterIndex(at: 999, chapters: chapters()) == 2)
    }

    @Test("currentChapterIndex returns 0 for empty chapter list")
    func emptyChapters() {
        #expect(PlaybackTimer.currentChapterIndex(at: 42, chapters: []) == 0)
    }

    @Test("format mm:ss renders seconds with leading zeros")
    func formatBasic() {
        #expect(PlaybackTimer.formatTime(0) == "00:00")
        #expect(PlaybackTimer.formatTime(9) == "00:09")
        #expect(PlaybackTimer.formatTime(65) == "01:05")
        #expect(PlaybackTimer.formatTime(3_599) == "59:59")
    }

    @Test("format h:mm:ss for >= 1 hour")
    func formatHours() {
        #expect(PlaybackTimer.formatTime(3_600) == "1:00:00")
        #expect(PlaybackTimer.formatTime(3_725) == "1:02:05")
    }

    @Test("Decoding chapters from JSON returns model values")
    func decodeChapters() throws {
        let json = """
        {"chapters":[
          {"start":0.0,"title":"Opening","summary":"intro"},
          {"start":120.5,"title":"Middle","summary":""}
        ]}
        """
        let data = Data(json.utf8)
        let chapters = PlaybackTimer.decodeChapters(from: data)
        #expect(chapters.count == 2)
        #expect(chapters.first?.title == "Opening")
        #expect(chapters[1].start == 120.5)
    }

    @Test("Decoding chapters from nil or malformed data returns empty list")
    func decodeBad() {
        #expect(PlaybackTimer.decodeChapters(from: nil).isEmpty)
        #expect(PlaybackTimer.decodeChapters(from: Data("not json".utf8)).isEmpty)
    }

    @Test("Decoding a ChaptersWrapper with an empty array returns an empty list")
    func decodeEmptyArray() {
        let json = #"{"chapters":[]}"#
        let chapters = PlaybackTimer.decodeChapters(from: Data(json.utf8))
        #expect(chapters.isEmpty)
    }

    @Test("Decoding a chapter with missing summary yields an empty summary")
    func decodeMissingSummary() {
        let json = #"{"chapters":[{"start":0.0,"title":"Opening"}]}"#
        let chapters = PlaybackTimer.decodeChapters(from: Data(json.utf8))
        #expect(chapters.count == 1)
        #expect(chapters.first?.summary == "")
        #expect(chapters.first?.title == "Opening")
    }
}
