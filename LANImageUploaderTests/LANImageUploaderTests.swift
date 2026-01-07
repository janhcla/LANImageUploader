//
//  LANImageUploaderTests.swift
//  LANImageUploaderTests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Testing
import Foundation
import UIKit
@testable import LANImageUploader

struct LANImageUploaderTests {

    @Test @MainActor func appDataInitialization() async throws {
        let mockFile = MockFileService()
        let mockUpload = MockImageUploadService()
        let mockDiscovery = MockNetworkDiscovery()
        
        let appData = AppData(
            fileService: mockFile,
            uploadService: mockUpload,
            discoveryService: mockDiscovery,
            hapticService: HapticFeedbackService.shared
        )
        
        #expect(appData.images.isEmpty)
        #expect(appData.scanStatus == "")
    }

    @Test @MainActor func appDataArchiveImages() async throws {
        let mockFile = MockFileService()
        mockFile.archiveImagesResult = (saved: 5, existing: 2)
        
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: HapticFeedbackService.shared
        )
        
        await appData.saveImagesToDatedFolder()
        
        #expect(appData.scanStatus.contains("5 images saved"))
        #expect(appData.scanStatus.contains("2 images were already saved"))
    }

    @Test @MainActor func appDataArchiveImagesError() async throws {
        let mockFile = MockFileService()
        mockFile.archiveImagesError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disk Full"])
        
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: HapticFeedbackService.shared
        )
        
        await appData.saveImagesToDatedFolder()
        
        #expect(appData.scanStatus.contains("Failed to save images"))
        #expect(appData.scanStatus.contains("Disk Full"))
    }

    @Test func connectionStatusEnumExists() async throws {
        let status = ConnectionStatus.disconnected
        #expect(status == .disconnected)
        
        let discoveryStatus = ConnectionStatus.discovery(.subnetScan(progress: 0.5))
        if case .discovery(let state) = discoveryStatus {
            #expect(state == .subnetScan(progress: 0.5))
        } else {
            #expect(Bool(false), "Expected discovery state")
        }
    }
    
    @Test @MainActor func discoveryStatusReportingWorks() async throws {
        let mockDiscovery = MockNetworkDiscovery()
        
        final class StatusCollector: @unchecked Sendable {
            var statuses: [ConnectionStatus] = []
            func add(_ status: ConnectionStatus) {
                statuses.append(status)
            }
        }
        
        let collector = StatusCollector()
        
        let _ = try await mockDiscovery.retrieveNetworkInfo(
            targetFolder: "test",
            username: "user",
            password: "password",
            directIP: nil,
            port: nil,
            onStatus: { status in
                collector.add(status)
            }
        )
        
        #expect(collector.statuses.contains(where: { 
            if case .connecting = $0 { return true }
            return false
        }))
    }

    @Test func connectionErrorMappingExists() async throws {
        let authError = ConnectionError.authenticationFailed
        #expect(authError.localizedDescription.contains("password"))
        
        let hostError = ConnectionError.hostNotFound("192.168.1.1")
        #expect(hostError.localizedDescription.contains("192.168.1.1"))
    }

    @Test func calculateRefractionOffset() async throws {
        let depth: CGFloat = 10.0
        let angle: Double = 45.0 // Degrees
        
        let offset = LiquidGlassUtils.calculateRefractionOffset(depth: depth, angle: angle)
        
        // At 45 degrees, x and y should be equal
        #expect(abs(offset.width - offset.height) < 0.001)
        #expect(offset.width > 0)
    }
}
