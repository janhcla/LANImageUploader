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
    var validatedConnectionResult: NetworkInfo = NetworkInfo(serverIP: "192.168.1.1", shareName: "MockShare", targetDirectory: nil)
    var validatedConnectionError: Error?
    private(set) var validatedConnectionArguments: (serverIP: String, shareName: String, targetDirectory: String?, port: Int?)?
    
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

    func validateConnection(
        serverIP: String,
        shareName: String,
        targetDirectory: String?,
        username: String,
        password: String,
        port: Int?,
        onStatus: (@Sendable (ConnectionStatus) -> Void)?
    ) async throws -> NetworkInfo {
        validatedConnectionArguments = (serverIP, shareName, targetDirectory, port)
        if let validatedConnectionError {
            throw validatedConnectionError
        }
        onStatus?(.connecting(serverIP))
        return validatedConnectionResult
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
