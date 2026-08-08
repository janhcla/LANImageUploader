//
//  LANImageUploaderTests.swift
//  LANImageUploaderTests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Testing
import Foundation
import UIKit
import ImageIO
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

    @Test func fileNameValidationMatchesWindowsSMBRules() {
        #expect(FileNameValidation.isValid("Consultation 2026-08-07"))
        #expect(FileNameValidation.isValid("patient_note.v2"))
        #expect(!FileNameValidation.isValid("CON"))
        #expect(!FileNameValidation.isValid("con.txt"))
        #expect(!FileNameValidation.isValid("note?.jpg"))
        #expect(!FileNameValidation.isValid("trailing."))
        #expect(!FileNameValidation.isValid("line\nfeed"))
    }

    @Test func scannerCapturePolicyNeverConfiguresOrCapturesAudio() {
        #expect(!ScannerCapturePolicy.automaticallyConfiguresApplicationAudioSession)
        #expect(!ScannerCapturePolicy.includesAudioInput)
    }

    @Test func visionRectangleConvertsToTopLeftCoordinates() {
        let crop = DocumentCrop.visionNormalized(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.2),
            bottomLeft: CGPoint(x: 0.1, y: 0.2)
        )

        #expect(abs(crop.topLeft.x - 0.1) < 0.0001)
        #expect(abs(crop.topLeft.y - 0.1) < 0.0001)
        #expect(abs(crop.topRight.x - 0.9) < 0.0001)
        #expect(abs(crop.topRight.y - 0.1) < 0.0001)
        #expect(abs(crop.bottomRight.x - 0.9) < 0.0001)
        #expect(abs(crop.bottomRight.y - 0.8) < 0.0001)
        #expect(abs(crop.bottomLeft.x - 0.1) < 0.0001)
        #expect(abs(crop.bottomLeft.y - 0.8) < 0.0001)
    }

    @Test func cropMapsBetweenAspectFillVideoAndPhotoCoordinates() throws {
        let detected = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.9)
        )

        let portrait = try #require(detected.mapped(
            fromAspectFillImageSize: CGSize(width: 1080, height: 1920),
            toImageSize: CGSize(width: 3024, height: 4032)
        ))
        #expect(abs(portrait.topLeft.x - 0.2) < 0.001)
        #expect(abs(portrait.topRight.x - 0.8) < 0.001)
        #expect(abs(portrait.topLeft.y - 0.1) < 0.001)

        let landscape = try #require(detected.mapped(
            fromAspectFillImageSize: CGSize(width: 1920, height: 1080),
            toImageSize: CGSize(width: 4032, height: 3024)
        ))
        #expect(abs(landscape.topLeft.x - 0.1) < 0.001)
        #expect(abs(landscape.topLeft.y - 0.2) < 0.001)
        #expect(abs(landscape.bottomLeft.y - 0.8) < 0.001)
    }

    @Test func documentCropValidationRejectsUnsafeGeometry() {
        let valid = DocumentCrop(
            topLeft: CGPoint(x: 0.12, y: 0.08),
            topRight: CGPoint(x: 0.88, y: 0.1),
            bottomRight: CGPoint(x: 0.84, y: 0.92),
            bottomLeft: CGPoint(x: 0.16, y: 0.9)
        )
        let tiny = DocumentCrop(
            topLeft: CGPoint(x: 0.45, y: 0.45),
            topRight: CGPoint(x: 0.55, y: 0.45),
            bottomRight: CGPoint(x: 0.55, y: 0.55),
            bottomLeft: CGPoint(x: 0.45, y: 0.55)
        )
        let crossing = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft: CGPoint(x: 0.1, y: 0.9)
        )
        let outside = DocumentCrop(
            topLeft: CGPoint(x: -0.2, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.9)
        )
        let flat = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.48),
            topRight: CGPoint(x: 0.9, y: 0.48),
            bottomRight: CGPoint(x: 0.9, y: 0.52),
            bottomLeft: CGPoint(x: 0.1, y: 0.52)
        )

        #expect(valid.isValidForPerspectiveCorrection())
        #expect(!tiny.isValidForPerspectiveCorrection())
        #expect(!crossing.isValidForPerspectiveCorrection())
        #expect(!outside.isValidForPerspectiveCorrection())
        #expect(!flat.isValidForPerspectiveCorrection())
    }

    @Test func fullFrameCropMapsToCoreImageExtent() {
        let extent = CGRect(x: 20, y: 40, width: 1200, height: 1600)
        let points = DocumentCrop.fullFrame.coreImagePoints(in: extent)

        #expect(points.topLeft == CGPoint(x: 20, y: 1640))
        #expect(points.topRight == CGPoint(x: 1220, y: 1640))
        #expect(points.bottomRight == CGPoint(x: 1220, y: 40))
        #expect(points.bottomLeft == CGPoint(x: 20, y: 40))
    }

    @Test func visionOrientationMatchesCaptureRotationAngle() {
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 0) == .up)
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 90) == .right)
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 180) == .down)
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 270) == .left)
        #expect(DocumentCaptureOrientation.orientedSize(
            CGSize(width: 1920, height: 1080),
            orientation: .right
        ) == CGSize(width: 1080, height: 1920))
    }

    @Test @MainActor func invalidPerspectiveCropFallsBackToOriginalImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 200, height: 300),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        }
        let crossing = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft: CGPoint(x: 0.1, y: 0.9)
        )

        let rendered = DocumentImageProcessor.renderedImage(source, crop: crossing)

        #expect(rendered.size == source.size)
    }

    @Test @MainActor func validPerspectiveCropProducesNonBlackImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 240, height: 320),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 320))
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(4)
            context.stroke(CGRect(x: 30, y: 25, width: 180, height: 270))
        }
        let crop = DocumentCrop(
            topLeft: CGPoint(x: 0.12, y: 0.08),
            topRight: CGPoint(x: 0.88, y: 0.08),
            bottomRight: CGPoint(x: 0.88, y: 0.92),
            bottomLeft: CGPoint(x: 0.12, y: 0.92)
        )

        let rendered = DocumentImageProcessor.renderedImage(source, crop: crop)

        #expect(rendered.size.width > 0)
        #expect(rendered.size.height > 0)
        #expect(try Self.centerBrightness(of: rendered) > 0.9)
    }

    @Test @MainActor func scanWithoutConfidentCropRemainsDocumentScan() async throws {
        let mockFile = MockFileService()
        mockFile.saveImageResult = URL(fileURLWithPath: "/tmp/mock/images/scan.jpg")
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let image = try #require(Self.makeImage())

        let captured = try await appData.saveCapturedImage(
            image,
            crop: nil,
            isDocumentScan: true
        )

        #expect(captured.crop == nil)
        #expect(captured.isDocumentScan)
    }

    @Test func onboardingCoversTheApprovedFourChapterFlow() {
        #expect(OnboardingPage.allCases == [.privacy, .capture, .organize, .ready])
        #expect(OnboardingPage.capture.message.localizedCaseInsensitiveContains("multi-page"))
        #expect(OnboardingPage.organize.message.localizedCaseInsensitiveContains("PDF"))
        #expect(OnboardingPage.ready.detailItems.contains { $0.title == "Settings > Server Connection" })
    }

    @Test func helpContentCoversEveryTopic() {
        for topic in HelpTopic.allCases {
            #expect(!topic.articles.isEmpty, "Expected at least one article for \(topic.title)")
        }
    }

    @Test func helpSearchIndexesTitlesKeywordsAndSteps() {
        #expect(HelpContent.search("multi-page").contains { $0.id == "scan-document" })
        #expect(HelpContent.search("direct IP").contains { $0.id == "connect-server" })
        #expect(HelpContent.search("page numbers compression").contains { $0.id == "pdf-settings" })
    }

    @Test func helpSearchRequiresEverySearchTerm() {
        let results = HelpContent.search("server password")

        #expect(results.contains { $0.id == "connect-server" })
        #expect(!results.contains { $0.id == "capture-photo" })
    }

    @Test func helpExplainsUploadBoundaryAndImmediateScanPersistence() {
        let limits = HelpContent.articles.first { $0.id == "scope-and-limitations" }
        let scanReview = HelpContent.articles.first { $0.id == "review-scan" }

        #expect(limits?.steps.contains { $0.localizedCaseInsensitiveContains("does not") } == true)
        #expect(limits?.tip?.localizedCaseInsensitiveContains("successful upload") == true)
        #expect(scanReview?.steps.contains { $0.localizedCaseInsensitiveContains("saved to Gallery immediately") } == true)
    }

    @Test func serverConnectionRequiresEveryUploadCredential() {
        let complete = ServerSettings(
            serverIP: "192.168.1.10",
            shareName: "Images",
            targetDirectory: nil,
            username: "uploader",
            port: nil
        )
        let missingShare = ServerSettings(
            serverIP: "192.168.1.10",
            shareName: " ",
            targetDirectory: nil,
            username: "uploader",
            port: nil
        )

        #expect(ServerConnectionReadiness.isComplete(settings: complete, password: "secret"))
        #expect(!ServerConnectionReadiness.isComplete(settings: complete, password: nil))
        #expect(!ServerConnectionReadiness.isComplete(settings: missingShare, password: "secret"))
    }

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

        let captureID = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        let captured = try await appData.saveCapturedImage(image, capturedAt: date, id: captureID)

        #expect(mockFile.savedImages.count == 1)
        #expect(mockFile.savedImages.first?.fileName == "IMG_20260515_101112_12345678.jpg")
        #expect(captured.name == "IMG_20260515_101112_12345678")
        #expect(appData.images.map { $0.name } == ["IMG_20260515_101112_12345678"])
    }

    @Test @MainActor func scannerDataSavePreservesCompressedBytesAndUsesUniqueNames() async throws {
        let mockFile = MockFileService()
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let data = Data([0xff, 0xd8, 0xff, 0xd9])
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let firstID = UUID(uuidString: "aaaaaaaa-1234-1234-1234-123456789abc")!
        let secondID = UUID(uuidString: "bbbbbbbb-1234-1234-1234-123456789abc")!

        _ = try await appData.saveCapturedImageData(
            data,
            crop: .fullFrame,
            isDocumentScan: true,
            capturedAt: date,
            id: firstID
        )
        _ = try await appData.saveCapturedImageData(
            data,
            crop: .fullFrame,
            isDocumentScan: true,
            capturedAt: date,
            id: secondID
        )

        #expect(mockFile.savedImages.map(\.data) == [data, data])
        #expect(mockFile.savedImages[0].fileName != mockFile.savedImages[1].fileName)
        #expect(mockFile.savedImages[0].fileName.hasSuffix("_aaaaaaaa.jpg"))
        #expect(mockFile.savedImages[1].fileName.hasSuffix("_bbbbbbbb.jpg"))
    }

    @Test @MainActor func retakeSaveUsesUniqueNamesAndPreservesIDs() async throws {
        let mockFile = MockFileService()
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let image = try #require(Self.makeImage())
        let firstID = UUID(uuidString: "11111111-1234-1234-1234-123456789abc")!
        let secondID = UUID(uuidString: "22222222-1234-1234-1234-123456789abc")!

        let first = try await appData.saveCapturedUIImage(image, suggestedPrefix: "RETAKE", id: firstID)
        let second = try await appData.saveCapturedUIImage(image, suggestedPrefix: "RETAKE", id: secondID)

        #expect(first.id == firstID)
        #expect(second.id == secondID)
        #expect(mockFile.savedImages.count == 2)
        #expect(mockFile.savedImages[0].fileName != mockFile.savedImages[1].fileName)
        #expect(mockFile.savedImages[0].fileName.hasSuffix("_11111111.jpg"))
        #expect(mockFile.savedImages[1].fileName.hasSuffix("_22222222.jpg"))
    }

    @Test @MainActor func replacingRetakenImageDoesNotLeaveTheOldQueueEntry() {
        let appData = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let oldImage = CapturedImage(
            id: UUID(uuidString: "11111111-1234-1234-1234-123456789abc")!,
            name: "old",
            fileURL: URL(fileURLWithPath: "/tmp/mock/images/old.jpg")
        )
        let replacement = CapturedImage(
            id: UUID(uuidString: "22222222-1234-1234-1234-123456789abc")!,
            name: "replacement",
            fileURL: URL(fileURLWithPath: "/tmp/mock/images/replacement.jpg")
        )
        appData.images = [oldImage]
        appData.selectedImageIDs = [oldImage.id]

        appData.replaceImage(withID: oldImage.id, with: replacement)

        #expect(appData.images.count == 1)
        #expect(appData.images.first?.id == replacement.id)
        #expect(appData.images.first?.name == "replacement")
        #expect(appData.selectedImageIDs.isEmpty)
    }

    @Test func capturedImageTimestampFormatterIsDeterministicAndThreadSafe() async throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 10
        components.minute = 11
        components.second = 12
        let date = try #require(components.date)

        let timestamps = await withTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<32 {
                group.addTask {
                    CapturedImageTimestampFormatter.shared.string(
                        from: date,
                        timeZone: TimeZone(secondsFromGMT: 0)!
                    )
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        #expect(timestamps.count == 32)
        #expect(timestamps.allSatisfy { $0 == "20260515_101112" })
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

    @Test @MainActor func injectedInMemoryPasswordStoreIsProcessLocalAndDoesNotUseKeychain() throws {
        let firstStore = InMemoryServerPasswordStore()
        let secondStore = InMemoryServerPasswordStore()
        let firstAppData = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService(),
            passwordStore: firstStore
        )
        let secondAppData = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService(),
            passwordStore: secondStore
        )

        try firstAppData.savePassword("first-process-password")

        #expect(firstAppData.getPassword() == "first-process-password")
        #expect(secondAppData.getPassword() == nil)
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
        
        let outcome = await appData.saveImagesToDatedFolder()
        
        #expect(appData.scanStatus.contains("5 images saved"))
        #expect(appData.scanStatus.contains("2 images were already saved"))
        #expect(outcome == .saved(savedCount: 5, alreadySavedCount: 2))
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
        
        let outcome = await appData.saveImagesToDatedFolder()
        
        #expect(appData.scanStatus.contains("Failed to save images"))
        #expect(appData.scanStatus.contains("Disk Full"))
        #expect(outcome == .failed(message: "Disk Full"))
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

        let outcome = await appData.saveImagesToDatedFolder()

        #expect(appData.scanStatus == "No images to save.")
        #expect(outcome == .noImages)
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

    @Test @MainActor func appDataDeletionFailureKeepsImageAndSelection() async {
        let mockFile = MockFileService()
        mockFile.removeItemError = CocoaError(.fileWriteUnknown)
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let image = CapturedImage(name: "protected", fileURL: URL(fileURLWithPath: "/tmp/mock/images/protected.jpg"))
        appData.images = [image]
        appData.selectedImageIDs = [image.id]

        let succeeded = await appData.deleteSelectedImages()

        #expect(!succeeded)
        #expect(appData.images.map(\.id) == [image.id])
        #expect(appData.selectedImageIDs == [image.id])
        #expect(mockFile.removedItems.isEmpty)
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

    @Test func smbConnectionTargetKeepsConfiguredShareAndOptionalDirectorySeparate() throws {
        let shareRoot = try #require(SMBConnectionTarget(shareName: " MediaCaptureShare ", targetDirectory: " / "))
        #expect(shareRoot.shareName == "MediaCaptureShare")
        #expect(shareRoot.targetDirectory == nil)

        let nestedDirectory = try #require(SMBConnectionTarget(shareName: "MediaCaptureShare", targetDirectory: "Data/MediaCapture"))
        #expect(nestedDirectory.shareName == "MediaCaptureShare")
        #expect(nestedDirectory.targetDirectory == "Data/MediaCapture")

        let sharePrefixedDirectory = try #require(SMBConnectionTarget(shareName: "MediaCaptureShare", targetDirectory: "MediaCaptureShare/Data/MediaCapture"))
        #expect(sharePrefixedDirectory.targetDirectory == "Data/MediaCapture")
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

    @Test @MainActor func pendingUploadDeletionKeepsOnlyUnremovedDerivativesForRetry() async {
        let first = UploadableFile(
            id: UUID(), name: "first", fileURL: URL(fileURLWithPath: "/tmp/mock/first.jpg"), kind: .jpeg
        )
        let second = UploadableFile(
            id: UUID(), name: "second", fileURL: URL(fileURLWithPath: "/tmp/mock/second.jpg"), kind: .jpeg
        )
        let third = UploadableFile(
            id: UUID(), name: "third", fileURL: URL(fileURLWithPath: "/tmp/mock/third.jpg"), kind: .jpeg
        )
        var removedURLs: [URL] = []

        let result = await PendingUploadFileDeletion.removeSequentially([first, second, third]) { url in
            if url == second.fileURL {
                throw CocoaError(.fileWriteUnknown)
            }
            removedURLs.append(url)
        }

        #expect(removedURLs == [first.fileURL])
        #expect(result.remainingFiles.map(\.id) == [second.id, third.id])
        #expect(result.error != nil)
    }

    @Test @MainActor func pendingUploadRetryRetainsOriginalSourceIDsUntilQueueIsCleared() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let first = UploadableFile(
            id: UUID(), name: "first", fileURL: URL(fileURLWithPath: "/tmp/mock/first.jpg"),
            kind: .jpeg, sourceImageIDs: [firstSourceID]
        )
        let second = UploadableFile(
            id: UUID(), name: "second", fileURL: URL(fileURLWithPath: "/tmp/mock/second.jpg"),
            kind: .jpeg, sourceImageIDs: [secondSourceID]
        )
        let appData = AppData(
            fileService: MockFileService(),
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )

        appData.setPendingUploadFiles([first, second])
        appData.retainPendingUploadFilesForRetry([second])

        #expect(appData.pendingUploadFiles?.map(\.id) == [second.id])
        #expect(appData.pendingUploadSourceImageIDs == [firstSourceID, secondSourceID])

        appData.clearPendingUploadFiles()
        #expect(appData.pendingUploadSourceImageIDs == nil)
    }

    @Test @MainActor func galleryOperationGateDoesNotLetCancelledOperationFinishReplacement() {
        let gate = GalleryOperationGate()
        let cancelledOperation = gate.begin()
        gate.cancel()
        let replacementOperation = gate.begin()

        #expect(!gate.finish(cancelledOperation))
        #expect(gate.isCurrent(replacementOperation))
        #expect(gate.finish(replacementOperation))
        #expect(!gate.isCurrent(replacementOperation))
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

    @Test @MainActor func restorePurchasesMarksFullUnlockWhenVerifiedEntitlementIsFound() async {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)
        let purchaseManager = StoreKitPurchaseManager(restorePurchasesAction: { true })

        await purchaseManager.restorePurchases(accessController: access)

        #expect(access.state.isFullAppUnlocked)
        #expect(purchaseManager.restorationStatus == .restored)
        #expect(!purchaseManager.isRestoring)
    }

    @Test @MainActor func restorePurchasesReportsWhenNoEntitlementIsFound() async {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)
        let purchaseManager = StoreKitPurchaseManager(restorePurchasesAction: { false })

        await purchaseManager.restorePurchases(accessController: access)

        #expect(!access.state.isFullAppUnlocked)
        #expect(purchaseManager.restorationStatus == .noRestorablePurchase)
        #expect(!purchaseManager.isRestoring)
    }

    @Test @MainActor func restorePurchasesReportsStoreKitErrors() async {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)
        let purchaseManager = StoreKitPurchaseManager(restorePurchasesAction: {
            throw CocoaError(.fileReadUnknown)
        })

        await purchaseManager.restorePurchases(accessController: access)

        #expect(!access.state.isFullAppUnlocked)
        #expect(purchaseManager.restorationStatus?.isError == true)
        #expect(purchaseManager.restorationStatus?.message.contains("Unable to restore purchases") == true)
        #expect(!purchaseManager.isRestoring)
    }

    @Test @MainActor func restorePurchasesIgnoresRepeatedRequestsWhileRestoring() async {
        let store = InMemoryPremiumAccessStore()
        let access = PremiumAccessController(store: store)
        var restoreInvocationCount = 0
        let purchaseManager = StoreKitPurchaseManager(restorePurchasesAction: {
            restoreInvocationCount += 1
            try await Task.sleep(for: .milliseconds(100))
            return true
        })

        let firstRestore = Task { @MainActor in
            await purchaseManager.restorePurchases(accessController: access)
        }
        await Task.yield()

        #expect(purchaseManager.isRestoring)
        await purchaseManager.restorePurchases(accessController: access)
        #expect(restoreInvocationCount == 1)

        await firstRestore.value
        #expect(purchaseManager.restorationStatus == .restored)
    }

    @Test @MainActor func restorePurchaseErrorPreservesExistingFullUnlock() async {
        let store = InMemoryPremiumAccessStore()
        store.hasPurchasedFullUnlock = true
        let access = PremiumAccessController(store: store)
        let purchaseManager = StoreKitPurchaseManager(restorePurchasesAction: {
            throw CocoaError(.fileReadUnknown)
        })

        await purchaseManager.restorePurchases(accessController: access)

        #expect(access.state.isFullAppUnlocked)
        #expect(purchaseManager.restorationStatus?.isError == true)
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

    @Test func autoCapturePageGateOnlyReleasesAfterMeaningfulMovement() {
        let captured = DocumentCrop.fullFrame
        let samePage = DocumentCrop.fullFrame
        let nextPage = DocumentCrop(
            topLeft: CGPoint(x: 0.2, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomRight: CGPoint(x: 0.8, y: 0.8),
            bottomLeft: CGPoint(x: 0.2, y: 0.8)
        )

        #expect(!DocumentCaptureQuality.hasMovedToNextPage(from: captured, to: samePage))
        #expect(DocumentCaptureQuality.hasMovedToNextPage(from: captured, to: nextPage))
        #expect(!DocumentCaptureQuality.hasMovedToNextPage(from: nil, to: nextPage))
    }

    @Test func pdfCompressionProfilesBecomeProgressivelySmaller() {
        #expect(PDFCompressionLevel.medium.jpegQuality < PDFCompressionLevel.light.jpegQuality)
        #expect(PDFCompressionLevel.high.jpegQuality < PDFCompressionLevel.medium.jpegQuality)
        #expect(PDFCompressionLevel.medium.maxPixelDimension < PDFCompressionLevel.light.maxPixelDimension)
        #expect(PDFCompressionLevel.high.maxPixelDimension < PDFCompressionLevel.medium.maxPixelDimension)
    }

    @Test func pdfGenerationRemovesPartialOutputWhenPageCannotBeRendered() async throws {
        let outputName = "partial-(UUID().uuidString)"
        let missingSource = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-(UUID().uuidString).jpg")
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(
                name: "missing",
                fileURL: missingSource,
                crop: .fullFrame,
                isDocumentScan: true
            ),
            rotation: .degrees0
        )

        await #expect(throws: (any Error).self) {
            try await PDFGenerationService.shared.generatePDF(
                from: [item],
                outputName: outputName,
                settings: PDFSettings()
            )
        }

        let remaining = try FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(outputName) }
        #expect(remaining.isEmpty)
    }

    @Test func cancelledPDFGenerationDoesNotCreateAnOutputFile() async throws {
        let outputName = "cancelled-\(UUID().uuidString)"
        let missingSource = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).jpg")
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(name: "cancelled", fileURL: missingSource),
            rotation: .degrees0
        )

        let task = Task {
            try await PDFGenerationService.shared.generatePDF(
                from: [item],
                outputName: outputName,
                settings: PDFSettings()
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Cancelled PDF generation unexpectedly completed")
        } catch is CancellationError {
            // Expected: cancellation is checked before creating the output file.
        } catch {
            Issue.record("Unexpected PDF cancellation error: \(error.localizedDescription)")
        }

        let remaining = try FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(outputName) }
        #expect(remaining.isEmpty)
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

    @Test func generatedPDFUsesLegacyCompatibleJPEGColorSpace() async throws {
        let source = Self.makeCompressionTestImage(size: CGSize(width: 800, height: 1100))
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(source.jpegData(compressionQuality: 1)).write(to: sourceURL)
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(name: "scan", fileURL: sourceURL, crop: .fullFrame, isDocumentScan: true),
            rotation: .degrees0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let pdf = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "compatible",
            settings: PDFSettings(includePageNumbers: false)
        )
        defer { try? FileManager.default.removeItem(at: pdf) }

        let contents = try Data(contentsOf: pdf)
        #expect(contents.starts(with: Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x33, 0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A])))
        #expect(contents.range(of: Data("/Filter /DCTDecode".utf8)) != nil)
        #expect(contents.range(of: Data("/ColorSpace /DeviceRGB".utf8)) != nil)
        #expect(contents.range(of: Data("/ICCBased".utf8)) == nil)
        #expect(contents.range(of: Data("\nendstream".utf8)) != nil)

        let text = try #require(String(data: contents, encoding: .isoLatin1))
        let xrefStart = try #require(text.range(of: "\nxref\n")?.upperBound)
        let xrefRemainder = text[xrefStart...]
        let xrefEnd = try #require(xrefRemainder.range(of: "\ntrailer\n")?.lowerBound)
        let xrefSection = xrefRemainder[..<xrefEnd]
        #expect(xrefSection.utf8.allSatisfy { $0 < 128 })
        #expect(xrefSection.contains(" 00000 n "))
    }

    @Test func generatedPDFAnchorsPageNumbersToFooter() async throws {
        let source = Self.makeCompressionTestImage(size: CGSize(width: 1200, height: 700))
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(source.jpegData(compressionQuality: 1)).write(to: sourceURL)
        let item = GalleryItem(
            id: UUID(),
            capturedImage: CapturedImage(name: "landscape", fileURL: sourceURL, crop: .fullFrame, isDocumentScan: true),
            rotation: .degrees0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let pdf = try await PDFGenerationService.shared.generatePDF(
            from: [item],
            outputName: "footer",
            settings: PDFSettings(includePageNumbers: true)
        )
        defer { try? FileManager.default.removeItem(at: pdf) }

        let text = try #require(String(data: Data(contentsOf: pdf), encoding: .isoLatin1))
        #expect(text.contains("12.000 Td (1 / 1) Tj ET"))
    }

    @Test func generatedPDFHandles100SequentialPagesWithoutDroppingPages() async throws {
        let source = Self.makeCompressionTestImage(size: CGSize(width: 320, height: 480))
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(source.jpegData(compressionQuality: 1)).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let items = (0..<100).map { index in
            GalleryItem(
                id: UUID(),
                capturedImage: CapturedImage(
                    name: "page-\(index + 1)",
                    fileURL: sourceURL,
                    crop: .fullFrame,
                    isDocumentScan: true
                ),
                rotation: .degrees0
            )
        }

        let pdf = try await PDFGenerationService.shared.generatePDF(
            from: items,
            outputName: "hundred-pages",
            settings: PDFSettings(
                includePageNumbers: false,
                jpegQuality: 0.5,
                maxPixelDimension: 800
            )
        )
        defer { try? FileManager.default.removeItem(at: pdf) }

        let text = try #require(String(data: Data(contentsOf: pdf), encoding: .isoLatin1))
        let pageObjectCount = text.components(separatedBy: "/Type /Page /Parent").count - 1
        #expect(pageObjectCount == items.count)
        #expect(text.contains("/Count 100"))
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

    @Test @MainActor func deleteRetainedImagesWithIDsKeepsUnuploadedImages() async {
        let mockFile = MockFileService()
        let appData = AppData(
            fileService: mockFile,
            uploadService: MockImageUploadService(),
            discoveryService: MockNetworkDiscovery(),
            hapticService: MockHapticFeedbackService()
        )
        let first = CapturedImage(name: "page-1", fileURL: URL(fileURLWithPath: "/tmp/mock/images/page-1.jpg"))
        let second = CapturedImage(name: "page-2", fileURL: URL(fileURLWithPath: "/tmp/mock/images/page-2.jpg"))
        let third = CapturedImage(name: "page-3", fileURL: URL(fileURLWithPath: "/tmp/mock/images/page-3.jpg"))
        appData.images = [first, second, third]
        appData.selectedImageIDs = [first.id, third.id]

        await appData.deleteRetainedImages(withIDs: [first.id, second.id])

        #expect(appData.images.map(\.id) == [third.id])
        #expect(appData.selectedImageIDs == [third.id])
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

    private static func centerBrightness(of image: UIImage) throws -> CGFloat {
        let cgImage = try #require(image.cgImage)
        let x = cgImage.width / 2
        let y = cgImage.height / 2
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(
            cgImage,
            in: CGRect(x: -x, y: y - cgImage.height, width: cgImage.width, height: cgImage.height)
        )
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
    }
}

private final class InMemoryPremiumAccessStore: PremiumAccessPersisting {
    var successfulUploadCount = 0
    var hasPurchasedFullUnlock = false
    var isPremiumOverrideEnabled = false
}
