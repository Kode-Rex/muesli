//
//  MuesliRecordingLiveActivityBundle.swift
//  MuesliRecordingLiveActivity
//
//  Widget extension entry point. Hosts the Live Activity for the
//  recording flow; the host app starts/updates/ends it via
//  LiveActivityController.
//

import WidgetKit
import SwiftUI

@main
struct MuesliRecordingLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RecordingActivityWidget()
    }
}
