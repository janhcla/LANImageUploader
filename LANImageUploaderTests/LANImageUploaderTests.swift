//
//  LANImageUploaderTests.swift
//  LANImageUploaderTests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Testing
import Foundation
@testable import LANImageUploader

struct LANImageUploaderTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func connectionStatusEnumExists() async throws {
        // This test will fail to compile initially because ConnectionStatus doesn't exist yet
        let status = ConnectionStatus.disconnected
        #expect(status == .disconnected)
        
        let discoveryStatus = ConnectionStatus.discovery(.subnetScan(progress: 0.5))
        if case .discovery(let state) = discoveryStatus {
            #expect(state == .subnetScan(progress: 0.5))
        } else {
            #expect(Bool(false), "Expected discovery state")
        }
        
        let connectingStatus = ConnectionStatus.connecting("192.168.1.100")
        if case .connecting(let ip) = connectingStatus {
            #expect(ip == "192.168.1.100")
        } else {
             #expect(Bool(false), "Expected connecting state")
        }
        
        let failureStatus = ConnectionStatus.failure(.timeout)
        if case .failure(let error) = failureStatus {
            #expect(error == .timeout)
        } else {
            #expect(Bool(false), "Expected failure state")
        }
    }
    
    @Test func discoveryStateEnumExists() async throws {
        let state = DiscoveryState.bonjourSearch
        #expect(state == .bonjourSearch)
        
        let resolving = DiscoveryState.resolving("_smb._tcp.")
        #expect(resolving == .resolving("_smb._tcp."))
    }

    @Test func discoveryStatusReportingWorks() async throws {
        // This test verifies that retrieveNetworkInfo reports status changes.
        final class StatusCollector: @unchecked Sendable {
            private let queue = DispatchQueue(label: "status.collector")
            var statuses: [ConnectionStatus] = []
            func add(_ status: ConnectionStatus) {
                queue.sync { statuses.append(status) }
            }
            func get() -> [ConnectionStatus] {
                queue.sync { statuses }
            }
        }
        
        let collector = StatusCollector()
        
        // We use invalid credentials to trigger a failure after discovery attempts
        // but we mainly care about the intermediate statuses.
        let _ = try? await NetworkDiscovery.shared.retrieveNetworkInfo(
            targetFolder: "test",
            username: "user",
            password: "wrong_password",
            onStatus: { status in
                collector.add(status)
            }
        )
        
        let receivedStatuses = collector.get()
        
        // Check if we received any status (either discovery, connecting, or failure)
        #expect(!receivedStatuses.isEmpty, "Should have received at least one status update")
    }

    @Test func waitForNetworkReturnsTrueInitially() async throws {
        // This test ensures waitForNetwork doesn't block indefinitely on simulator
        // where network should be available.
        let result = try await NetworkMonitor.shared.waitForNetwork(timeout: 2.0)
        #expect(result == true)
    }

    @Test func connectionErrorMappingExists() async throws {
        // This test verifies that we have a custom error type for detailed mapping
        let authError = ConnectionError.authenticationFailed
        #expect(authError.localizedDescription.contains("password"))
        
        let hostError = ConnectionError.hostNotFound("192.168.1.1")
        #expect(hostError.localizedDescription.contains("192.168.1.1"))
    }

}