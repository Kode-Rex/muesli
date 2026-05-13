# Phase 5: ChapteredPlaybackView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development.

**Goal:** Full-screen sheet that plays a note's audio with a custom scrubber, chapter markers from `note.chaptersJSON`, play/pause + skip-chapter buttons, and a tappable chapter list below.

**Architecture:**
- `ChapterModel` — value type decoded from `note.chaptersJSON`.
- `PlaybackTimer` — pure helper that, given `currentTime` and the chapter list, returns the current chapter index.
- `ChapteredPlaybackController` — `@Observable` class wrapping `AVAudioPlayer` so the view binds against published state (`currentTime`, `isPlaying`, `duration`). Exposes `play()`, `pause()`, `seek(to:)`, `skipChapter(offset:)`. Pure-logic helpers are unit tested; the AVAudioPlayer surface is exercised manually in the simulator.
- `ChapterScrubber` — SwiftUI component drawing the track + chapter ticks + thumb. Drag updates a binding; the host view commits to the controller's `seek(to:)`.
- `ChapteredPlaybackView` — assembles header + scrubber + controls + chapter list.
- `AugmentedNoteView` gains a "Listen" CTA that presents this view at chapter 0. Per-run tap-to-seek on quoteSpans/citations is deferred to a future enhancement (SwiftUI `Text` doesn't expose per-run gestures; would need a `UIViewRepresentable` wrapping `UITextView`).

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Scene ix.

**Deferred:**
- Per-run tap-to-seek inside AugmentedNoteView text. The blend-pipeline char ranges and AttributedString attribute keys are already in place; only the gesture-capture layer is missing.
- Background-audio Live Activity (Phase 8).

---

## File Structure

**Creating:**
- `src/mobile/Muesli/Views/Components/ChapterScrubber.swift`
- `src/mobile/Muesli/Views/Components/PlaybackTimer.swift` — pure helpers
- `src/mobile/Muesli/Views/ChapteredPlaybackController.swift` — `@Observable`
- `src/mobile/Muesli/Views/ChapteredPlaybackView.swift`
- `src/mobile/MuesliTests/Views/PlaybackTimerTests.swift`

**Modifying:**
- `src/mobile/Muesli/Views/AugmentedNoteView.swift` — add "Listen" button presenting `ChapteredPlaybackView`

---

## Task 1: `PlaybackTimer` pure helper + tests

**Files:**
- Create: `src/mobile/Muesli/Views/Components/PlaybackTimer.swift`
- Test: `src/mobile/MuesliTests/Views/PlaybackTimerTests.swift`

- [ ] **Step 1: Failing tests**

```swift
import Testing
import Foundation
@testable import Muesli

@Suite("Playback Timer Tests", .tags(.unit))
struct PlaybackTimerTests {

    private func chapters() -> [ChapterModel] {
        [
            ChapterModel(start: 0,   title: "Intro",   summary: ""),
            ChapterModel(start: 120, title: "Middle",  summary: ""),
            ChapterModel(start: 480, title: "Outro",   summary: "")
        ]
    }

    @Test("currentChapterIndex returns 0 before second chapter starts")
    func beforeSecond() {
        #expect(PlaybackTimer.currentChapterIndex(at: 0,   chapters: chapters()) == 0)
        #expect(PlaybackTimer.currentChapterIndex(at: 60,  chapters: chapters()) == 0)
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
        #expect(PlaybackTimer.formatTime(3599) == "59:59")
    }

    @Test("format hh:mm:ss for >= 1 hour")
    func formatHours() {
        #expect(PlaybackTimer.formatTime(3600) == "1:00:00")
        #expect(PlaybackTimer.formatTime(3725) == "1:02:05")
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
}
```

- [ ] **Step 2: Implement**

```swift
//
//  PlaybackTimer.swift
//  Muesli
//
//  Pure helpers used by the chaptered playback view: decode chapters,
//  pick the current chapter for a playback time, and format times.
//

import Foundation

struct ChapterModel: Equatable, Identifiable {
    var id: Int  // index in the list
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

    /// Decode chapters from the JSON shape SessionsService.runBlend persists
    /// to `note.chaptersJSON`. Returns an empty list on missing / malformed
    /// input.
    static func decodeChapters(from data: Data?) -> [ChapterModel] {
        guard let data else { return [] }
        guard let wrapper = try? JSONDecoder().decode(ChaptersWrapper.self, from: data) else { return [] }
        return wrapper.chapters.enumerated().map { idx, dto in
            ChapterModel(id: idx, start: dto.start, title: dto.title, summary: dto.summary ?? "")
        }
    }

    /// Returns the index of the chapter whose `start <= time`, picking the
    /// last satisfying. Returns 0 when chapters is empty or `time` is before
    /// the first chapter.
    static func currentChapterIndex(at time: Double, chapters: [ChapterModel]) -> Int {
        guard !chapters.isEmpty else { return 0 }
        var index = 0
        for (i, chapter) in chapters.enumerated() where chapter.start <= time {
            index = i
        }
        return index
    }

    /// mm:ss for times < 1h, h:mm:ss otherwise.
    static func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.toNearestOrEven)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
```

- [ ] **Step 3: Run, expect PASS**

```
xcodebuild test ... -only-testing:MuesliTests/PlaybackTimerTests
```

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/Views/Components/PlaybackTimer.swift \
        src/mobile/MuesliTests/Views/PlaybackTimerTests.swift
git commit -m "feat(ios): PlaybackTimer — chapter decode + index picker + formatter

Pure helpers underpinning the chaptered playback view. Decodes
note.chaptersJSON into ChapterModel values, returns the chapter
index for a given playback time (defaults to 0 before the first
chapter or for empty lists), and formats playback time as mm:ss
or h:mm:ss past one hour.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `ChapteredPlaybackController` (`AVAudioPlayer` wrapper)

**Files:**
- Create: `src/mobile/Muesli/Views/ChapteredPlaybackController.swift`

This is a thin observable wrapper. Not unit-tested directly (real audio sessions); the surface is small enough to verify in the simulator.

- [ ] **Step 1: Write the controller**

```swift
//
//  ChapteredPlaybackController.swift
//  Muesli
//
//  @Observable wrapper around AVAudioPlayer that publishes currentTime /
//  isPlaying / duration so the view binds against player state. Pure-logic
//  helpers live in PlaybackTimer.
//

import Foundation
import AVFoundation

@MainActor
@Observable
final class ChapteredPlaybackController {
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying: Bool = false
    private(set) var loadError: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(audioFileURL url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            self.player = p
            self.duration = p.duration
            self.currentTime = 0
            self.loadError = nil
        } catch {
            self.loadError = error.localizedDescription
            AppLogger.shared.error("ChapteredPlaybackController: failed to load \(url.lastPathComponent)", error: error)
        }
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = max(0, min(seconds, duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func skipChapter(offset: Int, chapters: [ChapterModel]) {
        let current = PlaybackTimer.currentChapterIndex(at: currentTime, chapters: chapters)
        let target = max(0, min(current + offset, chapters.count - 1))
        guard chapters.indices.contains(target) else { return }
        seek(to: chapters[target].start)
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/mobile/Muesli/Views/ChapteredPlaybackController.swift
git commit -m "feat(ios): ChapteredPlaybackController — @Observable AVAudioPlayer wrapper

Loads from a file URL, publishes currentTime/duration/isPlaying,
exposes play/pause/seek/skipChapter. A 0.25s timer polls
AVAudioPlayer's currentTime to drive the scrubber.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `ChapterScrubber` component

**Files:**
- Create: `src/mobile/Muesli/Views/Components/ChapterScrubber.swift`

- [ ] **Step 1: Write the component**

```swift
//
//  ChapterScrubber.swift
//  Muesli
//
//  Horizontal track with chapter-boundary ticks and a draggable thumb.
//  Reports drag through a binding; the host commits via `seek(to:)`.
//

import SwiftUI

struct ChapterScrubber: View {
    let duration: Double
    let chapters: [ChapterModel]
    @Binding var currentTime: Double
    /// Whether the user is currently dragging. The host should suspend
    /// timer-driven updates while this is true to avoid the thumb jumping.
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                // Played portion
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geo.size.width), height: 6)

                // Chapter ticks
                ForEach(chapters) { chapter in
                    let x = positionFor(time: chapter.start, in: geo.size.width)
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 2, height: 12)
                        .offset(x: x - 1)
                }

                // Thumb
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .shadow(radius: 2)
                    .offset(x: progressWidth(in: geo.size.width) - 9)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let pct = max(0, min(value.location.x / geo.size.width, 1))
                        currentTime = pct * max(1, duration)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 18)
    }

    private func progressWidth(in total: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let pct = currentTime / duration
        return CGFloat(max(0, min(pct, 1))) * total
    }

    private func positionFor(time: Double, in total: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let pct = time / duration
        return CGFloat(max(0, min(pct, 1))) * total
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/mobile/Muesli/Views/Components/ChapterScrubber.swift
git commit -m "feat(ios): ChapterScrubber — track + chapter ticks + draggable thumb

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `ChapteredPlaybackView` + AugmentedNoteView "Listen" CTA

**Files:**
- Create: `src/mobile/Muesli/Views/ChapteredPlaybackView.swift`
- Modify: `src/mobile/Muesli/Views/AugmentedNoteView.swift`

- [ ] **Step 1: Write the view**

```swift
//
//  ChapteredPlaybackView.swift
//  Muesli
//
//  Full-screen sheet: now-playing header + chapter scrubber + transport
//  controls + tappable chapter list. Audio comes from note.audioFilePath
//  via AudioRecordingManager.
//

import SwiftUI

struct ChapteredPlaybackView: View {
    let note: Note
    /// Initial seek target in seconds. Used when launched from a tap on a
    /// quote/citation; defaults to zero (start of audio).
    var startAt: Double = 0

    @State private var controller = ChapteredPlaybackController()
    @State private var chapters: [ChapterModel] = []
    @State private var isDragging = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.top, 12)

                if let err = controller.loadError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(err).font(.footnote).multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrubberRow
                        .padding(.horizontal)
                        .padding(.top, 8)
                    transport
                        .padding(.top, 16)

                    chapterList
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Now playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { setup() }
        .onDisappear { controller.pause() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chapter \(currentChapterDisplayIndex)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
            Text(note.title)
                .font(.title3.weight(.semibold))
            if let speaker = note.speaker, !speaker.isEmpty {
                Text(speaker).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrubberRow: some View {
        VStack(spacing: 6) {
            ChapterScrubber(
                duration: controller.duration,
                chapters: chapters,
                currentTime: Binding(
                    get: { controller.currentTime },
                    set: { newTime in
                        if isDragging {
                            controller.seek(to: newTime)
                        }
                    }
                ),
                isDragging: $isDragging
            )
            HStack {
                Text(PlaybackTimer.formatTime(controller.currentTime))
                Spacer()
                Text(PlaybackTimer.formatTime(controller.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 32) {
            Button {
                controller.skipChapter(offset: -1, chapters: chapters)
            } label: {
                Image(systemName: "backward.end.fill").font(.title2)
            }
            .disabled(chapters.isEmpty)

            Button {
                controller.toggle()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }

            Button {
                controller.skipChapter(offset: 1, chapters: chapters)
            } label: {
                Image(systemName: "forward.end.fill").font(.title2)
            }
            .disabled(chapters.isEmpty)
        }
    }

    private var chapterList: some View {
        List {
            ForEach(chapters) { chapter in
                Button {
                    controller.seek(to: chapter.start)
                    controller.play()
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chapter.title)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                            if !chapter.summary.isEmpty {
                                Text(chapter.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(PlaybackTimer.formatTime(chapter.start))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .padding(.top, 16)
    }

    private var currentChapterDisplayIndex: String {
        guard !chapters.isEmpty else { return "—" }
        let i = PlaybackTimer.currentChapterIndex(at: controller.currentTime, chapters: chapters)
        return String(format: "%02d", i + 1)
    }

    private func setup() {
        chapters = PlaybackTimer.decodeChapters(from: note.chaptersJSON)
        guard let path = note.audioFilePath,
              let url = AudioRecordingManager.shared.getRecordingURL(fileName: path) else {
            controller.loadError = "Audio file not found."
            return
        }
        controller.load(audioFileURL: url)
        if startAt > 0 { controller.seek(to: startAt) }
    }
}
```

- [ ] **Step 2: Add a "Listen" button to AugmentedNoteView**

In `AugmentedNoteView.swift`, add `@State private var showingPlayback = false` and a toolbar button:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showingPlayback = true
        } label: {
            Label("Listen", systemImage: "play.circle")
        }
        .disabled(note.audioFilePath == nil)
    }
}
.sheet(isPresented: $showingPlayback) {
    ChapteredPlaybackView(note: note)
}
```

- [ ] **Step 3: Build + smoke (manual simulator check optional)**

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/Views/ChapteredPlaybackView.swift \
        src/mobile/Muesli/Views/AugmentedNoteView.swift
git commit -m "feat(ios): ChapteredPlaybackView + AugmentedNoteView Listen CTA

Full-screen sheet plays note audio with a chapter-aware scrubber,
play/pause + skip-chapter buttons, and a tappable chapter list
underneath. Each chapter row jumps the playhead to its start and
resumes playback.

AugmentedNoteView gains a Listen button in the toolbar that
presents this view (disabled when no audio file is attached).
Per-run tap-to-seek inside the note body remains deferred; the
attribute keys carrying transcript timestamps stay in place for
when that lands.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 done when

- Four tasks committed.
- `PlaybackTimerTests` green (7 cases).
- Build green.
- Simulator smoke: a note with sample audio shows the Listen button, opens the player, scrubber jumps to chapter boundaries on the skip buttons.

## Next plan

Phase 6 wires `ChatView` (iOS side) against the chat backend already shipped in Phase 2.
