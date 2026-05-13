//
//  LiveActivityController.swift
//  Muesli
//
//  Thin wrapper around ActivityKit for the recording Live Activity.
//  Gracefully degrades to a no-op when:
//    - Running on iOS < 16.2
//    - The widget extension target hasn't been added yet
//    - The user has disabled Live Activities in Settings
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    private var current: Activity<RecordingActivityAttributes>?

    func start(title: String, sessionId: UUID) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.shared.info("LiveActivity: not enabled (no widget extension or user-disabled); skipping")
            return
        }
        let attributes = RecordingActivityAttributes(
            title: title,
            sessionId: sessionId,
            startedAt: Date()
        )
        let initialState = RecordingActivityAttributes.ContentState(elapsedSeconds: 0, isPaused: false)
        do {
            current = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            AppLogger.shared.warning("LiveActivity: start failed — \(error.localizedDescription)")
        }
    }

    func update(elapsedSeconds: Int, isPaused: Bool) async {
        guard let current else { return }
        let state = RecordingActivityAttributes.ContentState(elapsedSeconds: elapsedSeconds, isPaused: isPaused)
        await current.update(.init(state: state, staleDate: nil))
    }

    func end() async {
        guard let current else { return }
        await current.end(dismissalPolicy: .immediate)
        self.current = nil
    }
}
