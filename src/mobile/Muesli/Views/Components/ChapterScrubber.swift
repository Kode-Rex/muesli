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
    let currentTime: Double
    /// Invoked with the target time during drag and on commit. The host
    /// chooses whether each call should be a seek (which it does for both
    /// taps and drag updates so the playhead tracks the finger).
    let onSeek: (Double) -> Void

    /// When non-nil, the scrubber is being dragged; render this value as
    /// the thumb position instead of `currentTime` so the bar tracks the
    /// finger even if the controller's timer overwrites currentTime in
    /// the same frame.
    @State private var dragValue: Double?

    var body: some View {
        GeometryReader { geo in
            let displayTime = dragValue ?? currentTime
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(for: displayTime, in: geo.size.width), height: 6)

                ForEach(chapters) { chapter in
                    let x = progressWidth(for: chapter.start, in: geo.size.width)
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 2, height: 12)
                        .offset(x: x - 1)
                }

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .shadow(radius: 2)
                    .offset(x: progressWidth(for: displayTime, in: geo.size.width) - 9)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let pct = max(0, min(value.location.x / geo.size.width, 1))
                        let t = pct * max(1, duration)
                        dragValue = t
                        onSeek(t)
                    }
                    .onEnded { _ in
                        dragValue = nil
                    }
            )
        }
        .frame(height: 18)
    }

    private func progressWidth(for time: Double, in total: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let pct = time / duration
        return CGFloat(max(0, min(pct, 1))) * total
    }
}
