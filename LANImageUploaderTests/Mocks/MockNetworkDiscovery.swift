//
//  MockNetworkDiscovery.swift
//  LANImageUploaderTests
//
//  Created by AI on 06/01/2026.
//

import Foundation
import Network
@testable import LANImageUploader

final class MockNetworkDiscovery: NetworkDiscoveryProtocol, @unchecked Sendable {
    var networkInfoResult: NetworkInfo = NetworkInfo(ip: "192.168.1.1", port: 445, shareName: "MockShare")
    var networkInfoError: Error?
    
    func retrieveNetworkInfo(
        targetFolder: String?,
        username: String,
        password: String,
        directIP: String?,
        port: Int?,
        onStatus: @escaping @Sendable (String) -> Void
    ) async throws -> NetworkInfo {
        if let error = networkInfoError {
            throw error
        }
        onStatus("Mocking discovery...")
        return networkInfoResult
    }
}
