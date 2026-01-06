//
//  MockNetworkDiscovery.swift
//  LANImageUploaderTests
//
//  Created by AI on 06/01/2026.
//

import Foundation
import Network
@testable import LANImageUploader

@MainActor
final class MockNetworkDiscovery: NetworkDiscoveryProtocol, @unchecked Sendable {
    var networkMonitor: NetworkMonitor = .shared
    
    var networkInfoResult: NetworkInfo = NetworkInfo(serverIP: "192.168.1.1", shareName: "MockShare", targetDirectory: nil)
    var networkInfoError: Error?
    
    func retrieveNetworkInfo(
        targetFolder: String,
        username: String,
        password: String,
        directIP: String?,
        port: Int?,
        onStatus: (@Sendable (ConnectionStatus) -> Void)?
    ) async throws -> NetworkInfo {
        if let error = networkInfoError {
            throw error
        }
        onStatus?(.connecting("192.168.1.1"))
        return networkInfoResult
    }
    
    var discoveredHostsResult: [DiscoveredHost] = []
    func discoverAvailableHosts(onStatus: (@Sendable (ConnectionStatus) -> Void)?) async throws -> [DiscoveredHost] {
        onStatus?(.discovery(.bonjourSearch))
        return discoveredHostsResult
    }
    
    var availableSharesResult: [String] = ["MockShare"]
    func listAvailableShares(ipAddress: String, username: String, password: String, port: Int?) async throws -> [String] {
        return availableSharesResult
    }
}