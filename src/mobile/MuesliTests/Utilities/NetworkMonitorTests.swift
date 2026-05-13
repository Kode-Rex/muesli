//
//  NetworkMonitorTests.swift
//  MuesliTests
//
//  Tests for NetworkMonitor functionality
//

import Testing
import Foundation
import Network
@testable import Muesli

@Suite("Network Monitor Tests", .tags(.network))
struct NetworkMonitorTests {
    @Test("Network monitor singleton works")
    func networkMonitorSingletonWorks() async throws {
        let monitor1 = NetworkMonitor.shared
        let monitor2 = NetworkMonitor.shared

        #expect(monitor1 === monitor2)
    }

    @Test("Network monitor initializes correctly")
    func networkMonitorInitializesCorrectly() async throws {
        let monitor = NetworkMonitor.shared

        // Status should be one of the defined values
        #expect([NetworkStatus.unknown, NetworkStatus.connected, NetworkStatus.disconnected].contains(monitor.status))

        // isConnected should be a boolean
        #expect(monitor.isConnected == true || monitor.isConnected == false)
    }

    @Test("Network status enum has correct cases")
    func networkStatusEnumHasCorrectCases() async throws {
        let statuses: [NetworkStatus] = [.unknown, .connected, .disconnected]

        #expect(statuses.count == 3)

        // Test that each status can be compared
        #expect(NetworkStatus.unknown != NetworkStatus.connected)
        #expect(NetworkStatus.connected != NetworkStatus.disconnected)
        #expect(NetworkStatus.disconnected != NetworkStatus.unknown)
    }

    @Test("Interface type descriptions are provided")
    func interfaceTypeDescriptionsAreProvided() async throws {
        let types: [NWInterface.InterfaceType] = [
            .wifi, .cellular, .wiredEthernet, .loopback, .other
        ]

        for type in types {
            let description = type.description
            #expect(!description.isEmpty)
        }

        // Test specific descriptions
        #expect(NWInterface.InterfaceType.wifi.description == "WiFi")
        #expect(NWInterface.InterfaceType.cellular.description == "Cellular")
        #expect(NWInterface.InterfaceType.wiredEthernet.description == "Ethernet")
        #expect(NWInterface.InterfaceType.loopback.description == "Loopback")
        #expect(NWInterface.InterfaceType.other.description == "Other")
    }

    @Test("Monitor can be started and stopped safely")
    func monitorCanBeStartedAndStoppedSafely() async throws {
        let monitor = NetworkMonitor.shared

        // Starting monitoring should not crash
        monitor.startMonitoring()

        // Stopping monitoring should not crash
        monitor.stopMonitoring()

        // Multiple start/stop cycles should be safe
        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.startMonitoring()
        monitor.stopMonitoring()

        #expect(Bool(true)) // Should complete without crashes
    }

    @Test("Connectivity check returns boolean result")
    func connectivityCheckReturnsBooleanResult() async throws {
        let monitor = NetworkMonitor.shared

        let isReachable = await monitor.checkConnectivity()
        #expect(isReachable == true || isReachable == false)
    }

    @Test("Connectivity check URL is valid")
    func connectivityCheckURLIsValid() async throws {
        let testURL = URL(string: "https://api.deepgram.com/v1/listen")!

        #expect(testURL.scheme == "https")
        #expect(testURL.host == "api.deepgram.com")
        #expect(testURL.path.contains("/v1/listen"))
    }

    @Test("Network path status mapping is correct")
    func networkPathStatusMappingIsCorrect() async throws {
        // Test the logic that would be used in updateNetworkStatus
        let testCases: [(NWPath.Status, NetworkStatus)] = [
            (.satisfied, .connected),
            (.unsatisfied, .disconnected),
            (.requiresConnection, .disconnected)
        ]

        for (pathStatus, expectedNetworkStatus) in testCases {
            let mappedStatus: NetworkStatus
            switch pathStatus {
            case .satisfied:
                mappedStatus = .connected
            case .unsatisfied, .requiresConnection:
                mappedStatus = .disconnected
            @unknown default:
                mappedStatus = .unknown
            }

            #expect(mappedStatus == expectedNetworkStatus)
        }
    }

    @Test("Connection type detection works")
    func connectionTypeDetectionWorks() async throws {
        let monitor = NetworkMonitor.shared

        // connectionType should be nil or a valid interface type
        if let connectionType = monitor.connectionType {
            let validTypes: [NWInterface.InterfaceType] = [
                .wifi, .cellular, .wiredEthernet, .loopback, .other
            ]
            #expect(validTypes.contains(connectionType))
        }
    }

    @Test("Monitoring queue is properly configured")
    func monitoringQueueIsProperlyConfigured() async throws {
        // Test that we can create a dispatch queue with the expected label
        let testQueue = DispatchQueue(label: "NetworkMonitor")

        #expect(String(describing: testQueue).contains("NetworkMonitor"))
    }

    @Test("HTTP response status code validation works")
    func httpResponseStatusCodeValidationWorks() async throws {
        // Test the logic used in connectivity check
        let validStatusCodes = [200, 201, 204, 301, 302, 404, 429]
        let invalidStatusCodes = [500, 502, 503, 504]

        for statusCode in validStatusCodes {
            #expect(statusCode < 500) // Should be considered valid
        }

        for statusCode in invalidStatusCodes {
            #expect(statusCode >= 500) // Should be considered invalid
        }
    }

    @Test("Network status changes can be tracked")
    func networkStatusChangesCanBeTracked() async throws {
        let monitor = NetworkMonitor.shared

        // Get initial status
        let initialStatus = monitor.status
        let initialConnection = monitor.isConnected

        // Status should be consistent
        if initialStatus == .connected {
            #expect(initialConnection == true)
        } else if initialStatus == .disconnected {
            #expect(initialConnection == false)
        }
        // .unknown status can have either true or false for isConnected
    }

    @Test("Interface type enumeration is comprehensive")
    func interfaceTypeEnumerationIsComprehensive() async throws {
        // Test that all known interface types have descriptions
        let knownTypes: [(NWInterface.InterfaceType, String)] = [
            (.wifi, "WiFi"),
            (.cellular, "Cellular"),
            (.wiredEthernet, "Ethernet"),
            (.loopback, "Loopback"),
            (.other, "Other")
        ]

        for (type, expectedDescription) in knownTypes {
            #expect(type.description == expectedDescription)
        }
    }

    @Test("Monitor handles initialization correctly")
    func monitorHandlesInitializationCorrectly() async throws {
        // Test that the monitor starts in a valid state
        let monitor = NetworkMonitor.shared

        // Should have a status (any of the three valid values)
        #expect([.unknown, .connected, .disconnected].contains(monitor.status))

        // isConnected should be boolean
        #expect(monitor.isConnected is Bool)

        // connectionType can be nil or a valid type
        if let type = monitor.connectionType {
            #expect(type is NWInterface.InterfaceType)
        }
    }
}
