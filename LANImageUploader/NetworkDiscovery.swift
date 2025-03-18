//
//  NetworkDiscovery.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 13/03/2025.
//

import SwiftUI
import Foundation
import AMSMB2
import Network

// Your existing NetworkInfo struct comes from AppData.swift, so don't redefine it here

internal func retrieveNetworkInfo(targetFolder: String, username: String, password: String, directIP: String? = nil, port: Int? = nil) async throws -> NetworkInfo {
    print("Starting network info retrieval...")
    
    guard NetworkMonitor.shared.isConnected else {
        throw NSError(domain: "NetworkDiscovery", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No network connection available. Please check your Wi-Fi connection."])
    }
    
    if let directIP = directIP, !directIP.isEmpty {
        print("Attempting direct connection to: \(directIP) with port: \(String(describing: port))")
        do {
            let client = SMB2Manager(
                url: URL(string: "smb://\(directIP)")!,
                credential: URLCredential(user: username, password: password, persistence: .forSession)
            )!
            try await client.connectShare(name: "smb") // Replace "smb" with actual share name logic if needed
            let shareName = "smb" // Temporary; adjust based on your NAS
            try await client.disconnectShare()
            return NetworkInfo(serverIP: directIP, shareName: shareName, targetDirectory: targetFolder.isEmpty ? nil : targetFolder)
        } catch {
            print("Direct IP connection failed: \(error.localizedDescription)")
            // Fall back to discovery
        }
    }
    
    print("Starting network discovery...")
    let services = try await discoverSMBServers()
    guard !services.isEmpty else {
        throw NSError(domain: "NetworkDiscovery", code: -3,
            userInfo: [NSLocalizedDescriptionKey: "No SMB servers found on the network"])
    }
    
    // Try connecting to each discovered service
    for service in services {
        do {
            let ipAddress = try await resolveService(service)
            print("Attempting connection to discovered server: \(ipAddress)")
            let networkInfo = try await attemptConnection(
                ipAddress: ipAddress,
                targetFolder: targetFolder,
                username: username,
                password: password,
                port: port
            )
            return networkInfo
        } catch {
            print("Connection attempt failed for service: \(error.localizedDescription)")
            continue
        }
    }
    
    throw NSError(domain: "NetworkDiscovery", code: -4,
        userInfo: [NSLocalizedDescriptionKey: "Could not connect to any SMB servers"])
}

private func connectToDirectIP(ip: String, targetFolder: String, username: String, password: String, port: Int? = nil) async throws -> NetworkInfo {
    return try await attemptConnection(
        ipAddress: ip,
        targetFolder: targetFolder,
        username: username,
        password: password,
        port: port
    )
}

private func attemptConnection(ipAddress: String, targetFolder: String, username: String, password: String, port: Int? = nil) async throws -> NetworkInfo {
    // Construct URL with optional port
    let urlString: String
    if let port = port {
        urlString = "smb://\(ipAddress):\(port)"
        print("Connecting to SMB with port: \(urlString)")
    } else {
        urlString = "smb://\(ipAddress)"
        print("Connecting to SMB with default port: \(urlString)")
    }
    
    guard let client = SMB2Manager(
        url: URL(string: urlString)!,
        credential: URLCredential(user: username, password: password, persistence: .forSession)
    ) else {
        throw NSError(domain: "NetworkDiscovery", code: -5,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client"])
    }
    
    do {
            try await client.connectShare(name: "IPC$")
            let shares = try await client.listShares()
            try await client.disconnectShare()
            
            print("Found shares: \(shares.map { $0.name })")
            
            // First check if the target folder is a share
            if shares.contains(where: { $0.name == targetFolder }) {
                print("Found target as share: \(targetFolder)")
                return NetworkInfo(serverIP: ipAddress, shareName: targetFolder, targetDirectory: nil)
            }
        
        // Then check if it's a directory within any share
        for share in shares {
            if try await directoryExistsInShare(client: client, share: share.name, directory: targetFolder) {
                print("Found target as directory in share: \(share.name)/\(targetFolder)")
                return NetworkInfo(serverIP: ipAddress, shareName: share.name, targetDirectory: targetFolder)
            }
        }
        
        throw NSError(domain: "NetworkDiscovery", code: -6,
            userInfo: [NSLocalizedDescriptionKey: "Target folder not found on server"])
    } catch {
        throw NSError(domain: "NetworkDiscovery", code: -7,
            userInfo: [NSLocalizedDescriptionKey: "Connection failed: \(error.localizedDescription)"])
    }
}

public func discoverSMBServers() async throws -> [NetService] {
    return try await withCheckedThrowingContinuation { continuation in
        let browser = NetServiceBrowser()
        let delegate = SMBServiceBrowserDelegate(continuation: continuation)
        
        // Hold strong references
        let _ = (browser, delegate)
        
        browser.includesPeerToPeer = true
        browser.delegate = delegate
        browser.searchForServices(ofType: "_smb._tcp", inDomain: "")
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            if !delegate.hasCompleted {
                browser.stop()
                continuation.resume(throwing: NSError(domain: "NetworkDiscovery", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Network discovery timed out. Please try again."]))
            }
        }
    }
}

final class SMBServiceBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    private let continuation: CheckedContinuation<[NetService], Error>
    private var foundServices: [NetService] = []
    private(set) var hasCompleted = false
    
    init(continuation: CheckedContinuation<[NetService], Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        foundServices.append(service)
        print("Found service: \(service.name)")
        if !moreComing && !hasCompleted {
            hasCompleted = true
            continuation.resume(returning: foundServices)
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        foundServices.removeAll { $0 == service }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        if hasCompleted { return }
        
        hasCompleted = true
        let errorCode = errorDict["NSNetServicesErrorCode"] as? Int ?? -1
        var errorMessage = "Failed to search for network services: Error \(errorCode)"
        
        switch errorCode {
        case -72008:
            errorMessage = "Network discovery is blocked. Please check your firewall settings and network permissions."
        case -72009:
            errorMessage = "Network discovery timed out. Please try again."
        default:
            errorMessage = "Failed to search for network services: \(errorDict)"
        }
        
        print("Network discovery error: \(errorMessage)")
        continuation.resume(throwing: NSError(domain: "NetworkDiscovery", code: errorCode,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]))
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Starting network service search...")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("Network service search stopped")
        if !hasCompleted {
            hasCompleted = true
            continuation.resume(returning: foundServices)
        }
    }
}

public func resolveService(_ service: NetService) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        let delegate = NetServiceResolveDelegate(continuation: continuation)
        
        // Hold strong reference
        let _ = delegate
        
        service.delegate = delegate
        service.resolve(withTimeout: 5.0)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            service.stop()
        }
    }
}

final class NetServiceResolveDelegate: NSObject, NetServiceDelegate {
    private let continuation: CheckedContinuation<String, Error>
    
    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let hostName = sender.hostName {
            print("Resolved service to host: \(hostName)")
            continuation.resume(returning: hostName.replacingOccurrences(of: ".local", with: ""))
        } else {
            continuation.resume(throwing: NSError(domain: "ResolveError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve hostname"]))
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        continuation.resume(throwing: NSError(domain: "ResolveError", code: -2, userInfo: errorDict))
    }
}

public func directoryExistsInShare(client: SMB2Manager, share: String, directory: String) async throws -> Bool {
    try await client.connectShare(name: share)
    let files = try await client.contentsOfDirectory(atPath: "")
    try await client.disconnectShare()
    return files.contains { $0.name == directory }
}

// End of file. No additional code.
