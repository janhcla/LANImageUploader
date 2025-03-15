//
//  NetworkMonitor.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//

import Network
import SwiftUI

@Observable
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected = false {
        didSet {
            print("Network connection state changed to: \(isConnected)")
        }
    }
    
    private init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                print("Network status updated - Connected: \(path.status == .satisfied)")
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
}

// End of file. No additional code.
