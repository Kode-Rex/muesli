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
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geo.size.width), height: 6)

                ForEach(chapters) { chapter in
                    let x = positionFor(time: chapter.start, in: geo.size.width)
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 2, height: 12)
                        .offset(x: x - 1)
                }

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
