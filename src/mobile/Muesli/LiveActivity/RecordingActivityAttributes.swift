//
//  RecordingActivityAttributes.swift
//  Muesli
//
//  Shared ActivityKit attributes for the recording Live Activity.
//  This type is also referenced by the Widget Extension target whose
//  UI renders the actual Dynamic Island / lock-screen content.
//
//  *** Widget Extension target setup (manual, one-time) ***
//
//  Live Activities REQUIRE a Widget Extension target. To enable the
//  Dynamic Island banner:
//
//  1. In Xcode: File → New → Target → Widget Extension. Name it
//     `MuesliRecordingLiveActivity`, embed in the Muesli app target.
//  2. In the extension target, add this file via "Add Files to Target"
//     so the ActivityAttributes type is shared.
//  3. Replace the stock widget body with an `ActivityConfiguration` for
//     `RecordingActivityAttributes` rendering elapsed time + title.
//  4. Ensure Muesli's Info.plist has UIBackgroundModes including
//     "audio" so the recording survives backgrounding.
//
//  Until step 1 ships, `LiveActivityController.start()` no-ops because
//  `ActivityAuthorizationInfo().areActivitiesEnabled` returns false
//  with no hosting extension.
//

import Foundation
import ActivityKit

struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isPaused: Bool
    }

    var title: String
    var sessionId: UUID
    var startedAt: Date
}
