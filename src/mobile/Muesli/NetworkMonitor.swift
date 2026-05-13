//
//  NetworkMonitor.swift
//  Muesli
//
//  Network connectivity monitoring for transcription services
//

import Foundation
import Network
import SwiftUI

enum NetworkStatus {
    case unknown
    case connected
    case disconnected
}

@Observable
class NetworkMonitor: NetworkPort {

    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var status: NetworkStatus = .unknown
    private(set) var isConnected: Bool = false
    private(set) var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: queue)
        AppLogger.shared.info("Started network monitoring")
    }
    
    func stopMonitoring() {
        monitor.cancel()
        AppLogger.shared.info("Stopped network monitoring")
    }
    
    func checkConnectivity() async -> Bool {
        // Quick connectivity test
        guard isConnected else { return false }
        
        return await withCheckedContinuation { continuation in
            let url = URL(string: "https://api.deepgram.com/v1/listen")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0
            
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode < 500 {
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateNetworkStatus(path: NWPath) {
        let wasConnected = isConnected
        
        isConnected = path.status == .satisfied
        connectionType = path.availableInterfaces.first?.type
        
        switch path.status {
        case .satisfied:
            status = .connected
        case .unsatisfied, .requiresConnection:
            status = .disconnected
        @unknown default:
            status = .unknown
        }
        
        // Log connectivity changes
        if wasConnected != isConnected {
            if isConnected {
                AppLogger.shared.info("Network connected - \(connectionType?.description ?? "unknown type")")
            } else {
                AppLogger.shared.warning("Network disconnected")
            }
        }
    }
}

// MARK: - Extensions

extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}
