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
