//
//  NetworkMonitor.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//

import Network
import SwiftUI
@preconcurrency import ObjectiveC

@preconcurrency
@Observable
final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @MainActor
    private(set) var isConnected: Bool = false
    
    private init() {
        self.monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            print("Path update received - Status: \(path.status)")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateConnectionStatus(isConnected: path.status == .satisfied)
            }
        }
        
        monitor.start(queue: queue)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let initialConnected = self.monitor.currentPath.status == .satisfied
            self.updateConnectionStatus(isConnected: initialConnected)
            print("NetworkMonitor initialized - Initial connected: \(initialConnected)")
        }
    }

    @MainActor
    private func updateConnectionStatus(isConnected newValue: Bool) {
        guard isConnected != newValue else { return }
        isConnected = newValue
        print("Network connection state changed to: \(isConnected)")
        // Post notification when network state changes
        NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
    }
    
    @MainActor
    func waitForNetwork(timeout: TimeInterval = 10.0) async throws -> Bool {
        if monitor.currentPath.status == .satisfied {
            updateConnectionStatus(isConnected: true)
            return true
        }

        // If already connected, return immediately
        if self.isConnected { return true }
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var observer: NSObjectProtocol? = nil  // Declare observer variable first
            
            // Function to safely resume continuation and cleanup
            func safelyResume(with value: Bool) {
                guard !hasResumed else { return }
                hasResumed = true
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: value)
            }
            
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if !hasResumed {
                        safelyResume(with: false)
                    }
                } catch {
                    // Task was canceled, no need to do anything
                }
            }
            
            // Now create the observer
            observer = NotificationCenter.default.addObserver(
                forName: .networkStatusChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.monitor.currentPath.status == .satisfied {
                        self.updateConnectionStatus(isConnected: true)
                        timeoutTask.cancel()
                        safelyResume(with: true)
                    }
                }
            }
            
            // Check current status again
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.monitor.currentPath.status == .satisfied {
                    self.updateConnectionStatus(isConnected: true)
                    timeoutTask.cancel()
                    safelyResume(with: true)
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
    }
    
    @MainActor
    func checkCurrentStatus() {
        let path = monitor.currentPath
        print("Current path status: \(path.status)")
        updateConnectionStatus(isConnected: path.status == .satisfied)
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("NetworkMonitorStateChanged")
}
