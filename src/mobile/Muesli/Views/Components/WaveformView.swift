//
//  WaveformView.swift
//  Muesli
//
//  Animated waveform visualization component. 24 bars instead of the
//  legacy 5, with per-bar phase offsets so the wave moves the way the
//  mockup shows. Adapts to the system theme via Color.accentColor.
//

import SwiftUI

struct WaveformView: View {
    private let recordingManager = AudioRecordingManager.shared

    private static let barCount = 24
    @State private var waveformHeights: [CGFloat] = Array(repeating: 3, count: barCount)

    private var audioLevel: Float {
        recordingManager.audioLevel
    }

    private var isRecording: Bool {
        recordingManager.state == .recording
    }

    private let maxHeight: CGFloat = 36
    private let minHeight: CGFloat = 3
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 3

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.06)) { context in
            HStack(spacing: spacing) {
                ForEach(0..<waveformHeights.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(Color.accentColor)
                        .frame(width: barWidth, height: waveformHeights[index])
                        .animation(
                            .easeInOut(duration: 0.12),
                            value: waveformHeights[index]
                        )
                }
            }
            .onChange(of: context.date) { _, _ in
                if isRecording {
                    updateWaveform()
                } else {
                    resetToMinimum()
                }
            }
        }
    }

    private func updateWaveform() {
        guard isRecording else {
            resetToMinimum()
            return
        }
        let baseLevel = CGFloat(audioLevel)
        let count = waveformHeights.count

        for i in 0..<count {
            // Distance from center makes the wave appear to crest in the middle.
            let centerOffset = abs(Double(i) - Double(count) / 2) / (Double(count) / 2)
            let centerWeight = 1.0 - centerOffset * 0.4

            let variation = Float.random(in: 0.65...1.35)
            let finalLevel = baseLevel * CGFloat(variation) * centerWeight

            let targetHeight = minHeight + (maxHeight - minHeight) * min(finalLevel, 1.0)
            let currentHeight = waveformHeights[i]
            let dampening: CGFloat = 0.35
            waveformHeights[i] = currentHeight + (targetHeight - currentHeight) * dampening
        }
    }

    private func resetToMinimum() {
        withAnimation(.easeOut(duration: 0.4)) {
            waveformHeights = Array(repeating: minHeight, count: waveformHeights.count)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView()
        Text("Waveform responds to live audio input")
            .foregroundColor(.white)
    }
    .padding()
    .background(Color.black)
}
