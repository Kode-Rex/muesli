//
//  WaveformView.swift
//  Muesli
//
//  Animated waveform visualization component
//

import SwiftUI

struct WaveformView: View {
    // Directly reference the shared manager - SwiftUI will observe it
    private let recordingManager = AudioRecordingManager.shared

    @State private var waveformHeights: [CGFloat] = Array(repeating: 3, count: 5)

    // Computed properties from recording manager
    private var audioLevel: Float {
        recordingManager.audioLevel
    }

    private var isRecording: Bool {
        recordingManager.state == .recording
    }

    private let maxHeight: CGFloat = 30
    private let minHeight: CGFloat = 3
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            HStack(spacing: spacing) {
                ForEach(0..<waveformHeights.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(Color.green)
                        .frame(width: barWidth, height: waveformHeights[index])
                        .animation(
                            .easeInOut(duration: 0.1 + Double(index) * 0.02),
                            value: waveformHeights[index]
                        )
                }
            }
            .onAppear {
                AppLogger.shared.debug("WaveformView appeared")
            }
            .onChange(of: context.date) { _, _ in
                // Update waveform every 0.1 seconds
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

        // Convert audio level to visual heights
        let baseLevel = CGFloat(audioLevel)

        // Debug: Log audio level more frequently for debugging
        if Int.random(in: 1...5) == 1 { // Log roughly every 0.5 seconds
            AppLogger.shared.debug("WaveformView UPDATE: audioLevel=\(audioLevel), baseLevel=\(baseLevel), isRecording=\(isRecording), avgPower=\(recordingManager.averagePower), peakPower=\(recordingManager.peakPower)")
        }
        
        for i in 0..<waveformHeights.count {
            // Add some randomization and variation between bars
            let variation = Float.random(in: 0.7...1.3)
            let adjustedLevel = baseLevel * CGFloat(variation)
            
            // Different bars respond slightly differently for more natural look
            let responsiveness = [1.0, 0.8, 1.2, 0.9, 1.1][i]
            let finalLevel = adjustedLevel * responsiveness
            
            // Calculate height between min and max
            let targetHeight = minHeight + (maxHeight - minHeight) * min(finalLevel, 1.0)
            
            // Add some smoothing to prevent jittery movement
            let currentHeight = waveformHeights[i]
            let dampening: CGFloat = 0.3
            waveformHeights[i] = currentHeight + (targetHeight - currentHeight) * dampening
        }
    }
    
    private func resetToMinimum() {
        withAnimation(.easeOut(duration: 0.5)) {
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
