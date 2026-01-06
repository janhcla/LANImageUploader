//
//  NetworkDiscoveryProtocol.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation
import Network

protocol NetworkDiscoveryProtocol: MainActor {
    func retrieveNetworkInfo(
        targetFolder: String,
        username: String,
        password: String,
        directIP: String?,
        port: Int?,
        onStatus: (@Sendable (ConnectionStatus) -> Void)?
    ) async throws -> NetworkInfo
    
    func discoverAvailableHosts(
        onStatus: (@Sendable (ConnectionStatus) -> Void)?
    ) async throws -> [DiscoveredHost]
    
    func listAvailableShares(
        ipAddress: String,
        username: String,
        password: String,
        port: Int?
    ) async throws -> [String]
}
