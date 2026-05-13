//
//  FakeNetworkAdapter.swift
//  MuesliTests
//
//  In-memory network adapter for tests. Defaults to disconnected so
//  no test code path tries to reach a real host.
//

import Foundation
@testable import Muesli

final class FakeNetworkAdapter: NetworkPort {
    var stubIsConnected: Bool = false
    private(set) var startMonitoringCount = 0
    private(set) var stopMonitoringCount = 0

    var isConnected: Bool { stubIsConnected }

    func startMonitoring() { startMonitoringCount += 1 }
    func stopMonitoring() { stopMonitoringCount += 1 }
}
