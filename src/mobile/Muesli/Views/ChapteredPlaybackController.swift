//
//  ChapteredPlaybackController.swift
//  Muesli
//
//  @Observable wrapper around AVAudioPlayer. Publishes currentTime /
//  isPlaying / duration so the view binds against player state.
//

import Foundation
import AVFoundation

@MainActor
@Observable
final class ChapteredPlaybackController {
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying: Bool = false
    var loadError: String?

    private var player: AVAudioPlayer?
    // `Timer.invalidate()` is safe from any thread; the property is touched
    // from deinit (nonisolated) so it carries the unsafe annotation.
    nonisolated(unsafe) private var timer: Timer?

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

    /// Seeks the player. AVAudioPlayer.currentTime can be sticky for a frame
    /// or two when set while playing on some iOS versions; if the user reports
    /// hearing the prior position briefly, switch to a pause/seek/play cycle.
    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = max(0, min(seconds, duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Skips by `offset` chapters and resumes playback. Matches the
    /// chapter-list row's tap behavior so the user gets consistent
    /// playback-on-jump across all chapter-navigation entry points.
    func skipChapter(offset: Int, chapters: [ChapterModel]) {
        let current = PlaybackTimer.currentChapterIndex(at: currentTime, chapters: chapters)
        let target = max(0, min(current + offset, chapters.count - 1))
        guard chapters.indices.contains(target) else { return }
        seek(to: chapters[target].start)
        play()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        stopTimer()
        // The runloop fires on main; trust the isolation rather than spawning
        // a fresh Task four times per second.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
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
