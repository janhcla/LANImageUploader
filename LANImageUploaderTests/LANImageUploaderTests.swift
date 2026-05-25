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
            hapticService: MockHapticFeedbackService()
        )
        
        #expect(appData.images.isEmpty)
        #expect(appData.scanStatus == "")
    }

    @Test @MainActor func clearNamingDataClearsImageNameAndOCRText() async throws {
        let appData = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )

        appData.imageName = "IMG_001"
        appData.ocrText = "scanned text"

        appData.clearNamingData()

        #expect(appData.imageName.isEmpty)
        #expect(appData.ocrText.isEmpty)
    }

    @Test @MainActor func cameraSaveImageAppendsGalleryItem() async throws {
        let mockFile = MockFileService()
        mockFile.saveImageResult = URL(fileURLWithPath: "/tmp/mock/images/IMG_20260515_101112.jpg")
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let image = try #require(Self.makeImage())
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 10
        components.minute = 11
        components.second = 12
        let date = try #require(components.date)

        let captured = try await appData.saveCapturedImage(image, capturedAt: date)

        #expect(mockFile.savedImages.count == 1)
        #expect(mockFile.savedImages.first?.fileName == "IMG_20260515_101112.jpg")
        #expect(captured.name == "IMG_20260515_101112")
        #expect(appData.images.map { $0.name } == ["IMG_20260515_101112"])
    }

    @Test @MainActor func cameraSaveImageFailureDoesNotAppendGalleryItem() async throws {
        let mockFile = MockFileService()
        mockFile.saveImageError = NSError(domain: "test", code: 2)
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let image = try #require(Self.makeImage())

        await #expect(throws: (any Error).self) {
            try await appData.saveCapturedImage(image)
        }

        #expect(appData.images.isEmpty)
    }

    @Test @MainActor func persistentGalleryRestoresScannedPagesAndCropMetadata() throws {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.capturedImageQueue)
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try Data([0x01]).write(to: sourceURL)
        defer {
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.capturedImageQueue)
            try? FileManager.default.removeItem(at: sourceURL)
        }
        let crop = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.9)
        )
        let original = CapturedImage(name: "persisted", fileURL: sourceURL, crop: crop, isDocumentScan: true)

        let first = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService(),
            persistsImageQueue: true
        )
        first.images = [original]

        let restored = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService(),
            persistsImageQueue: true
        )

        #expect(restored.images.count == 1)
        #expect(restored.images.first?.id == original.id)
        #expect(restored.images.first?.crop == crop)
    }

    @Test @MainActor func appDataArchiveImages() async throws {
        let mockFile = MockFileService()
        mockFile.archiveImagesResult = (saved: 5, existing: 2)
        
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
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
            hapticService: MockHapticFeedbackService()
        )
        
        await appData.saveImagesToDatedFolder()
        
        #expect(appData.scanStatus.contains("Failed to save images"))
        #expect(appData.scanStatus.contains("Disk Full"))
    }

    @Test @MainActor func appDataArchiveNoImagesReportsNoImagesToSave() async throws {
        let mockFile = MockFileService()
        mockFile.archiveImagesResult = (saved: 0, existing: 0)
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )

        await appData.saveImagesToDatedFolder()

        #expect(appData.scanStatus == "No images to save.")
    }

    @Test @MainActor func appDataDeleteSelectedImagesRemovesFilesAndClearsSelection() async throws {
        let mockFile = MockFileService()
        let haptics = MockHapticFeedbackService()
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: haptics
        )
        let first = CapturedImage(name: "first", fileURL: URL(fileURLWithPath: "/tmp/mock/images/first.jpg"))
        let second = CapturedImage(name: "second", fileURL: URL(fileURLWithPath: "/tmp/mock/images/second.jpg"))
        appData.images = [first, second]
        appData.selectedImageIDs = [first.id]

        await appData.deleteSelectedImages()

        #expect(appData.images.map { $0.id } == [second.id])
        #expect(appData.selectedImageIDs.isEmpty)
        #expect(mockFile.removedItems == [first.fileURL])
        #expect(haptics.lastNotificationType == .success)
    }

    @Test @MainActor func appDataGetArchivedDates() async throws {
        let mockFile = MockFileService()
        let expectedDates = ["2024-01-01", "2024-01-02"]
        mockFile.getArchivedDatesResult = expectedDates

        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )

        let result = await appData.getArchivedDates()

        #expect(result == expectedDates)
    }

    @Test @MainActor func appDataGetImagesForDate() async throws {
        let mockFile = MockFileService()
        let testDate = "2024-01-01"
        let expectedURLs = [URL(fileURLWithPath: "/tmp/1.jpg"), URL(fileURLWithPath: "/tmp/2.jpg")]
        mockFile.getImagesForDateResult = expectedURLs

        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )

        let result = await appData.getImagesForDate(testDate)

        #expect(result == expectedURLs)
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

    @Test func uploadFailureDetailCombinesReasonAndGuidance() async throws {
        let detail = UploadFailureDetail(
            reason: "The server rejected the username or password.",
            guidance: "Open Settings and verify your SMB credentials.",
            action: .openSettings
        )

        #expect(detail.combinedMessage == "The server rejected the username or password.\nOpen Settings and verify your SMB credentials.")
        #expect(detail.action == .openSettings)
    }

    @Test func uploadErrorGuidanceMapsSettingsActions() async throws {
        #expect(ImageUploadService.UploadError.authenticationFailed.action == .openSettings)
        #expect(ImageUploadService.UploadError.shareNotFound("Images").action == .openSettings)
        #expect(ImageUploadService.UploadError.fileAlreadyExists("IMG_001").action == nil)
        #expect(ImageUploadService.UploadError.timeout.guidance.contains("Wi-Fi"))
        #expect(ImageUploadService.UploadError.accessDenied.errorDescription?.contains("Access denied") == true)
    }

    @Test @MainActor func mockUploadServiceRecordsUploadInputsAndProgress() async throws {
        final class ProgressRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var storage: [Double] = []

            func append(_ value: Double) {
                lock.lock()
                storage.append(value)
                lock.unlock()
            }

            var values: [Double] {
                lock.lock()
                defer { lock.unlock() }
                return storage
            }
        }

        let mockUpload = MockImageUploadService()
        let progress = ProgressRecorder()
        let image = CapturedImage(name: "IMG_001", fileURL: URL(fileURLWithPath: "/tmp/mock/images/IMG_001.jpg"))
        let settings = ServerSettings(
            serverIP: "192.168.1.10",
            shareName: "Images",
            targetDirectory: "Uploads",
            username: "user",
            port: 445
        )

        try await mockUpload.upload(
            image: image,
            settings: settings,
            password: "secret",
            overwrite: true,
            onProgress: { progress.append($0) }
        )

        #expect(mockUpload.uploadedImages.map { $0.id } == [image.id])
        #expect(mockUpload.overwriteValues == [true])
        #expect(mockUpload.passwords == ["secret"])
        #expect(mockUpload.settingsValues.first?.serverIP == "192.168.1.10")
        #expect(progress.values == [0.5, 1.0])
    }

    @Test @MainActor func premiumTrialStartsWithFifteenUploads() async throws {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)

        #expect(access.state.canUpload)
        #expect(access.state.remainingTrialUploads == 15)
        #expect(access.state.shouldShowTrialStatus)
    }

    @Test @MainActor func premiumTrialCountsSuccessfulUploads() async throws {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)

        access.recordSuccessfulUpload()
        access.recordSuccessfulUpload()

        #expect(access.state.successfulUploadCount == 2)
        #expect(access.state.remainingTrialUploads == 13)
        #expect(access.state.canUpload)
    }

    @Test @MainActor func premiumTrialBlocksAfterFifteenSuccessfulUploads() async throws {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)

        for _ in 0..<15 {
            access.recordSuccessfulUpload()
        }

        #expect(access.state.successfulUploadCount == 15)
        #expect(access.state.remainingTrialUploads == 0)
        #expect(!access.state.canUpload)
    }

    @Test @MainActor func developerModeTemporarilyUnlocksFullApp() async throws {
        let store = InMemoryPremiumAccessStore()
        store.successfulUploadCount = 15
        let access = PremiumAccessController(store: store)

        #expect(!access.state.canUpload)

        access.setDeveloperModeEnabled(true)
        #expect(access.state.isFullAppUnlocked)
        #expect(access.state.canUpload)
        #expect(!access.state.shouldShowTrialStatus)

        access.setDeveloperModeEnabled(false)
        #expect(!access.state.isFullAppUnlocked)
        #expect(!access.state.canUpload)
    }

    @Test @MainActor func purchasedUnlockPersistsWhenDeveloperModeIsOff() async throws {
        let store = InMemoryPremiumAccessStore()
        store.successfulUploadCount = 15
        let access = PremiumAccessController(store: store)

        access.markPurchasedFullUnlock()
        access.setDeveloperModeEnabled(false)

        #expect(access.state.isFullAppUnlocked)
        #expect(access.state.canUpload)
        #expect(!access.state.shouldShowTrialStatus)
    }

    @Test @MainActor func fullUnlockDoesNotConsumeAdditionalTrialUploads() async throws {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)

        access.markPurchasedFullUnlock()
        access.recordSuccessfulUpload()

        #expect(access.state.successfulUploadCount == 0)
        #expect(access.state.remainingTrialUploads == 15)
        #expect(access.state.canUpload)
    }

    private static func makeImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

private final class InMemoryPremiumAccessStore: PremiumAccessPersisting {
    var successfulUploadCount = 0
    var hasPurchasedFullUnlock = false
    var isDeveloperModeEnabled = false
}
