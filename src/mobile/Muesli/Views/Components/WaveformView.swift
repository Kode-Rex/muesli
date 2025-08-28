//
//  WaveformView.swift
//  Muesli
//
//  Animated waveform visualization component
//

import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    @State private var waveformHeights: [CGFloat] = Array(repeating: 3, count: 5)
    @State private var animationTimer: Timer?
    
    private let maxHeight: CGFloat = 30
    private let minHeight: CGFloat = 3
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 4
    
    var body: some View {
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
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isRecording) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
                resetToMinimum()
            }
        }
    }
    
    private func startAnimation() {
        stopAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                updateWaveform()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateWaveform() {
        guard isRecording else {
            resetToMinimum()
            return
        }
        
        // Convert audio level to visual heights
        let baseLevel = CGFloat(audioLevel)
        
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
        WaveformView(audioLevel: 0.3, isRecording: true)
        WaveformView(audioLevel: 0.7, isRecording: true)
        WaveformView(audioLevel: 0.0, isRecording: false)
    }
    .padding()
    .background(Color.black)
}
