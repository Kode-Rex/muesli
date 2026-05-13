//
//  BlendingOverlay.swift
//  Muesli
//
//  Visual representation of a Note's blend pipeline state. Hosts pick
//  between the inline (vertical-stack) presentation and a full-screen
//  modal-friendly variant via the `style` parameter. Spec Scene v.
//

import SwiftUI

struct BlendingOverlay: View {
    let status: BlendStatus
    var error: String?
    var style: Style = .inline

    enum Style {
        /// Stacked vertically; suitable for embedding inside ScrollView.
        case inline
        /// Centered with extra vertical padding; suitable for sheet overlay.
        case fullScreen
    }

    var body: some View {
        VStack(spacing: 12) {
            switch status {
            case .idle:
                indicator(systemImage: "clock", label: "Waiting to start…")
            case .transcribing, .transcribed:
                spinner(label: "Transcribing audio…")
            case .extracting:
                spinner(label: "Extracting slide text…")
            case .blending:
                spinner(label: "Blending notes with AI…")
            case .complete:
                indicator(systemImage: "checkmark.circle.fill",
                          label: "Done.",
                          tint: .green)
            case .failed:
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error ?? "Blend failed.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, style == .fullScreen ? 48 : 24)
    }

    private func spinner(label: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(style == .fullScreen ? .large : .regular)
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func indicator(systemImage: String, label: String, tint: Color = .secondary) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(tint)
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        BlendingOverlay(status: .transcribing)
        Divider()
        BlendingOverlay(status: .blending)
        Divider()
        BlendingOverlay(status: .failed, error: "Sonnet returned 502.")
    }
    .padding()
}
