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
    
    var isConnected: Bool {
        didSet {
            print("Network connection state changed to: \(isConnected)")
        }
    }
    
    private init() {
        self.monitor = NWPathMonitor()
        self.monitor.start(queue: queue)
        self.isConnected = monitor.currentPath.status == .satisfied
        print("NetworkMonitor initialized - Initial connected: \(isConnected)")
        
        monitor.pathUpdateHandler = { [weak self] path in
            print("Path update received - Status: \(path.status)")
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                print("Network status updated - Connected: \(path.status == .satisfied)")
            }
        }
    }
    
    func checkCurrentStatus() {
        let path = monitor.currentPath
        print("Current path status: \(path.status)")
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
}
