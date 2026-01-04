//
//  LANImageUploaderTests.swift
//  LANImageUploaderTests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Testing
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
    }
    
    @Test func discoveryStateEnumExists() async throws {
        let state = DiscoveryState.bonjourSearch
        #expect(state == .bonjourSearch)
        
        let resolving = DiscoveryState.resolving("_smb._tcp.")
        #expect(resolving == .resolving("_smb._tcp."))
    }

}