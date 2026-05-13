//
//  NetworkPort.swift
//  Muesli
//
//  Port (interface) for network reachability. Live adapter wraps
//  NWPathMonitor; tests use a fake that returns canned isConnected values.
//

import Foundation

protocol NetworkPort: AnyObject {
    var isConnected: Bool { get }
    func startMonitoring()
    func stopMonitoring()
}
