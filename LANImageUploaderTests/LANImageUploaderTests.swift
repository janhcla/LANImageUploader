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

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedValues: [Double] = []

    func append(_ value: Double) {
        lock.withLock {
            recordedValues.append(value)
        }
    }

    var values: [Double] {
        lock.withLock {
            recordedValues
        }
    }
}

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
        let original = CapturedImage(
            name: "persisted",
            fileURL: sourceURL,
            crop: crop,
            isDocumentScan: true,
            rotation: .degrees270
        )

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
        #expect(restored.images.first?.rotation == .degrees270)
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

    @Test @MainActor func premiumOverrideTemporarilyUnlocksFullAppWhenAllowed() async throws {
        let store = InMemoryPremiumAccessStore()
        store.successfulUploadCount = 15
        let access = PremiumAccessController(store: store, canUsePremiumOverride: { true })

        #expect(!access.state.canUpload)

        access.setPremiumOverrideEnabled(true)
        #expect(access.state.isFullAppUnlocked)
        #expect(access.state.canUpload)
        #expect(!access.state.shouldShowTrialStatus)

        access.setPremiumOverrideEnabled(false)
        #expect(!access.state.isFullAppUnlocked)
        #expect(!access.state.canUpload)
    }

    @Test @MainActor func premiumOverrideIsIgnoredWhenNotAllowed() async throws {
        let store = InMemoryPremiumAccessStore()
        store.successfulUploadCount = 15
        store.isPremiumOverrideEnabled = true
        let access = PremiumAccessController(store: store, canUsePremiumOverride: { false })

        #expect(!access.state.canUsePremiumOverride)
        #expect(!access.state.isPremiumOverrideEnabled)
        #expect(!access.state.isFullAppUnlocked)
        #expect(!access.state.canUpload)
    }

    @Test @MainActor func purchasedUnlockPersistsWhenDeveloperModeIsOff() async throws {
        let store = InMemoryPremiumAccessStore()
        store.successfulUploadCount = 15
        let access = PremiumAccessController(store: store)

        access.markPurchasedFullUnlock()
        access.setPremiumOverrideEnabled(false)

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

    @Test func photoFramingCropsAspectFillOutputToTallPreview() {
        let visible = PhotoCaptureFraming.normalizedVisibleRect(
            imageSize: CGSize(width: 400, height: 300),
            previewSize: CGSize(width: 300, height: 600)
        )

        #expect(abs(visible.width - 0.375) < 0.001)
        #expect(abs(visible.height - 1) < 0.001)
        #expect(abs(visible.midX - 0.5) < 0.001)
    }

    @Test func photoFramingProducesTheVisibleImageAspectRatio() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }

        let cropped = PhotoCaptureFraming.image(
            source,
            matchingAspectFillPreview: CGSize(width: 300, height: 600)
        )

        #expect(abs((cropped.size.width / cropped.size.height) - 0.5) < 0.01)
    }

    @Test func overlaySmoothingMovesTowardLatestDetectedCropWithoutReplacingIt() {
        let first = DocumentCrop.fullFrame
        let second = DocumentCrop(
            topLeft: CGPoint(x: 0.2, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomRight: CGPoint(x: 0.8, y: 0.8),
            bottomLeft: CGPoint(x: 0.2, y: 0.8)
        )

        let display = DocumentCaptureQuality.smoothedDisplayCrop(from: first, toward: second, factor: 0.5)

        #expect(display.topLeft == CGPoint(x: 0.1, y: 0.1))
        #expect(display.bottomRight == CGPoint(x: 0.9, y: 0.9))
        #expect(second.topLeft == CGPoint(x: 0.2, y: 0.2))
    }

    @Test func pdfCompressionProfilesBecomeProgressivelySmaller() {
        #expect(PDFCompressionLevel.medium.jpegQuality < PDFCompressionLevel.light.jpegQuality)
        #expect(PDFCompressionLevel.high.jpegQuality < PDFCompressionLevel.medium.jpegQuality)
        #expect(PDFCompressionLevel.medium.maxPixelDimension < PDFCompressionLevel.light.maxPixelDimension)
        #expect(PDFCompressionLevel.high.maxPixelDimension < PDFCompressionLevel.medium.maxPixelDimension)
    }

    @Test func highPDFCompressionProducesSmallerDocumentThanLightCompression() async throws {
        let size = CGSize(width: 1800, height: 2400)
        let source = Self.makeCompressionTestImage(size: size)
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(source.jpegData(compressionQuality: 1)).write(to: sourceURL)
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(name: "scan", fileURL: sourceURL, crop: .fullFrame, isDocumentScan: true),
            rotation: .degrees0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let light = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "light",
            settings: PDFSettings(
                jpegQuality: PDFCompressionLevel.light.jpegQuality,
                maxPixelDimension: PDFCompressionLevel.light.maxPixelDimension
            )
        )
        let high = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "high",
            settings: PDFSettings(
                jpegQuality: PDFCompressionLevel.high.jpegQuality,
                maxPixelDimension: PDFCompressionLevel.high.maxPixelDimension
            )
        )
        defer {
            try? FileManager.default.removeItem(at: light)
            try? FileManager.default.removeItem(at: high)
        }

        let lightSize = try Data(contentsOf: light).count
        let highSize = try Data(contentsOf: high).count
        #expect(highSize < lightSize)
    }

    @Test func pdfJPEGQualityChangesFileSizeWithoutDimensionChange() async throws {
        let source = Self.makeCompressionTestImage(size: CGSize(width: 1600, height: 2200))
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(source.jpegData(compressionQuality: 1)).write(to: sourceURL)
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(name: "scan", fileURL: sourceURL, crop: .fullFrame, isDocumentScan: true),
            rotation: .degrees0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let highQuality = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "quality-high",
            settings: PDFSettings(jpegQuality: 0.85, maxPixelDimension: 1600)
        )
        let lowQuality = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "quality-low",
            settings: PDFSettings(jpegQuality: 0.35, maxPixelDimension: 1600)
        )
        defer {
            try? FileManager.default.removeItem(at: highQuality)
            try? FileManager.default.removeItem(at: lowQuality)
        }

        #expect(try Data(contentsOf: lowQuality).count < Data(contentsOf: highQuality).count)
    }

    @Test @MainActor func deleteAllRetainedImagesClearsGalleryAndRemovesFiles() async {
        let mockFile = MockFileService()
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let first = CapturedImage(name: "page-1", fileURL: URL(fileURLWithPath: "/tmp/mock/images/page-1.jpg"))
        let second = CapturedImage(name: "page-2", fileURL: URL(fileURLWithPath: "/tmp/mock/images/page-2.jpg"))
        appData.images = [first, second]
        appData.selectedImageIDs = [first.id]

        await appData.deleteAllRetainedImages()

        #expect(appData.images.isEmpty)
        #expect(appData.selectedImageIDs.isEmpty)
        #expect(mockFile.removedItems == [first.fileURL, second.fileURL])
    }

    @Test func scanOverlayMapsNormalizedCropIntoAspectFillPreview() {
        let mapped = DocumentPreviewGeometry.points(
            for: DocumentCrop.fullFrame,
            imageSize: CGSize(width: 300, height: 400),
            previewBounds: CGRect(x: 0, y: 0, width: 400, height: 800)
        )

        #expect(abs(mapped.topLeft.x + 100) < 0.001)
        #expect(abs(mapped.topLeft.y) < 0.001)
        #expect(abs(mapped.bottomRight.x - 500) < 0.001)
        #expect(abs(mapped.bottomRight.y - 800) < 0.001)
    }

    private static func makeImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private static func makeCompressionTestImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            for row in stride(from: 0, to: Int(size.height), by: 12) {
                let hue = CGFloat((row / 12) % 60) / 60
                UIColor(hue: hue, saturation: 0.75, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: CGFloat(row), width: size.width, height: 12))
            }
            UIColor.black.setStroke()
            for column in stride(from: 0, to: Int(size.width), by: 19) {
                context.cgContext.move(to: CGPoint(x: CGFloat(column), y: 0))
                context.cgContext.addLine(to: CGPoint(x: CGFloat(column + 80), y: size.height))
            }
            context.cgContext.strokePath()
        }
    }
}

private final class InMemoryPremiumAccessStore: PremiumAccessPersisting {
    var successfulUploadCount = 0
    var hasPurchasedFullUnlock = false
    var isPremiumOverrideEnabled = false
}
