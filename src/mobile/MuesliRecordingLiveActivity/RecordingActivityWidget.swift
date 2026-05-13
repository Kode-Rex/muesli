//
//  RecordingActivityWidget.swift
//  MuesliRecordingLiveActivity
//
//  Live Activity UI for an in-progress recording. Lock screen shows
//  the talk title + elapsed time; Dynamic Island shows compact
//  red-dot + mm:ss and an expanded title + elapsed + paused status.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock-screen / banner UI.
            HStack(spacing: 12) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "record.circle")
                    .foregroundStyle(.red)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "record.circle")
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.subheadline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isPaused ? "Paused" : "Recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "record.circle")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
