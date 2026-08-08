//
//  GalleryModelsTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
import UIKit
@testable import LANImageUploader

struct GalleryModelsTests {
    @Test func scanCameraGalleryRouteUsesSinglePDFOutput() {
        #expect(CameraGalleryRoute(captureMode: .scan).outputMode == .singlePDF)
    }

    @Test func photoCameraGalleryRouteUsesSeparateImagesOutput() {
        #expect(CameraGalleryRoute(captureMode: .photo).outputMode == .separateImages)
    }

    @Test func cameraOffersAllSupportedUserFacingZoomTargets() {
        #expect(CameraZoomOption.preferredDisplayFactors == [0.5, 1, 2, 3, 4])
        #expect(CameraZoomOption(factor: 1, displayFactor: 1).label == "1x")
        #expect(CameraZoomOption(factor: 1.5, displayFactor: 1.5).label == "1.5x")
    }

    @Test func captureOrientationNormalizesAnglesAndSwapsOrientedDimensions() {
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: -90) == .left)
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 450) == .right)
        #expect(DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: 45) == .up)
        #expect(DocumentCaptureOrientation.orientedSize(
            CGSize(width: 1920, height: 1080), orientation: .right
        ) == CGSize(width: 1080, height: 1920))
        #expect(DocumentCaptureOrientation.orientedSize(
            CGSize(width: 1920, height: 1080), orientation: .up
        ) == CGSize(width: 1920, height: 1080))
    }

    @Test func aspectFillFramingHandlesInvalidDimensionsAndPreviewMapping() {
        #expect(PhotoCaptureFraming.normalizedVisibleRect(
            imageSize: .zero,
            previewSize: CGSize(width: 300, height: 300)
        ) == CGRect(x: 0, y: 0, width: 1, height: 1))

        let crop = DocumentCrop(
            topLeft: CGPoint(x: 0.2, y: 0.2),
            topRight: CGPoint(x: 0.8, y: 0.2),
            bottomRight: CGPoint(x: 0.8, y: 0.8),
            bottomLeft: CGPoint(x: 0.2, y: 0.8)
        )
        let mapped = DocumentPreviewGeometry.points(
            for: crop,
            imageSize: CGSize(width: 400, height: 300),
            previewBounds: CGRect(x: 0, y: 0, width: 300, height: 300)
        )

        #expect(mapped.topLeft.x == 30)
        #expect(mapped.topRight.x == 270)
        #expect(mapped.topLeft.y == 60)
        #expect(mapped.bottomLeft.y == 240)
    }

    @Test func visibleCropMatchesAspectFillPreviewFraming() {
        let crop = PhotoCaptureFraming.visibleCrop(
            imageSize: CGSize(width: 400, height: 300),
            previewSize: CGSize(width: 300, height: 300)
        )

        #expect(abs(crop.topLeft.x - 0.125) < 0.001)
        #expect(abs(crop.topRight.x - 0.875) < 0.001)
        #expect(crop.topLeft.y == 0)
        #expect(crop.bottomRight.y == 1)
        #expect(PhotoCaptureFraming.crop(.fullFrame, isVisibleIn: CGRect(x: 0, y: 0, width: 1, height: 1)))
        #expect(!PhotoCaptureFraming.crop(.fullFrame, isVisibleIn: CGRect(x: 0.125, y: 0, width: 0.75, height: 1)))
    }


    @Test func testImageRotationNextClockwise() {
        #expect(ImageRotation.degrees0.nextClockwise == .degrees90)
        #expect(ImageRotation.degrees90.nextClockwise == .degrees180)
        #expect(ImageRotation.degrees180.nextClockwise == .degrees270)
        #expect(ImageRotation.degrees270.nextClockwise == .degrees0)
    }

    @Test func documentCropClampsControlPointsToImageBounds() {
        let crop = DocumentCrop(
            topLeft: CGPoint(x: -0.2, y: 0.1),
            topRight: CGPoint(x: 1.4, y: -0.1),
            bottomRight: CGPoint(x: 1.1, y: 1.3),
            bottomLeft: CGPoint(x: -0.1, y: 1.2)
        ).clamped()

        #expect(crop.topLeft == CGPoint(x: 0, y: 0.1))
        #expect(crop.topRight == CGPoint(x: 1, y: 0))
        #expect(crop.bottomRight == CGPoint(x: 1, y: 1))
        #expect(crop.bottomLeft == CGPoint(x: 0, y: 1))
    }

    @Test func documentCaptureQualityRequiresLargeStraightStableCandidate() {
        let acceptable = DocumentCrop(
            topLeft: CGPoint(x: 0.12, y: 0.12),
            topRight: CGPoint(x: 0.88, y: 0.12),
            bottomRight: CGPoint(x: 0.88, y: 0.88),
            bottomLeft: CGPoint(x: 0.12, y: 0.88)
        )
        let tooSmall = DocumentCrop(
            topLeft: CGPoint(x: 0.42, y: 0.42),
            topRight: CGPoint(x: 0.58, y: 0.42),
            bottomRight: CGPoint(x: 0.58, y: 0.58),
            bottomLeft: CGPoint(x: 0.42, y: 0.58)
        )
        let angled = DocumentCrop(
            topLeft: CGPoint(x: 0.12, y: 0.12),
            topRight: CGPoint(x: 0.88, y: 0.12),
            bottomRight: CGPoint(x: 0.64, y: 0.88),
            bottomLeft: CGPoint(x: 0.35, y: 0.88)
        )

        #expect(DocumentCaptureQuality.isAcceptable(acceptable))
        #expect(!DocumentCaptureQuality.isAcceptable(tooSmall))
        #expect(!DocumentCaptureQuality.isAcceptable(angled))
        #expect(DocumentCaptureQuality.averageMovement(from: acceptable, to: acceptable) == 0)
    }

    @Test func capturedImageRoundTripPreservesEditableCropAndIdentity() throws {
        let crop = DocumentCrop(
            topLeft: CGPoint(x: 0.1, y: 0.15),
            topRight: CGPoint(x: 0.9, y: 0.1),
            bottomRight: CGPoint(x: 0.85, y: 0.9),
            bottomLeft: CGPoint(x: 0.15, y: 0.88)
        )
        let original = CapturedImage(
            name: "scan",
            fileURL: URL(fileURLWithPath: "/tmp/scan.jpg"),
            crop: crop,
            isDocumentScan: true,
            rotation: .degrees90
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapturedImage.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.crop == crop)
        #expect(decoded.isDocumentScan)
        #expect(decoded.rotation == .degrees90)
    }

    @Test func galleryItemEqualityTracksCropAndDisplayedNameChanges() {
        let id = UUID()
        let sourceURL = URL(fileURLWithPath: "/tmp/scan.jpg")
        var original = CapturedImage(id: id, name: "scan", fileURL: sourceURL)
        let item = GalleryItem(id: id, capturedImage: original, rotation: .degrees0)

        original.crop = DocumentCrop.fullFrame
        let croppedItem = GalleryItem(id: id, capturedImage: original, rotation: .degrees0)
        #expect(item != croppedItem)

        original.name = "renamed"
        let renamedItem = GalleryItem(id: id, capturedImage: original, rotation: .degrees0)
        #expect(croppedItem != renamedItem)
    }

    @Test func cropExportLeavesOriginalScanUnmodified() throws {
        let size = CGSize(width: 120, height: 160)
        let original = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 20, y: 25, width: 80, height: 110))
        }
        let originalURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        let originalData = try #require(original.jpegData(compressionQuality: 0.95))
        try originalData.write(to: originalURL)
        defer { try? FileManager.default.removeItem(at: originalURL) }

        let page = CapturedImage(
            name: "scan",
            fileURL: originalURL,
            crop: DocumentCrop(
                topLeft: CGPoint(x: 0.15, y: 0.12),
                topRight: CGPoint(x: 0.85, y: 0.12),
                bottomRight: CGPoint(x: 0.85, y: 0.88),
                bottomLeft: CGPoint(x: 0.15, y: 0.88)
            ),
            isDocumentScan: true,
            rotation: .degrees90
        )

        let exportedURL = try DocumentImageProcessor.exportJPEG(
            for: page,
            rotation: page.rotation,
            name: "export",
            maxPixelDimension: 2500,
            jpegQuality: 0.85
        )
        defer { try? FileManager.default.removeItem(at: exportedURL) }

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect(try Data(contentsOf: originalURL) == originalData)
    }

    @Test func exportScalesCorrectedImageDuringSingleRenderPipeline() throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        let originalURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try #require(original.jpegData(compressionQuality: 0.95)).write(to: originalURL)
        defer { try? FileManager.default.removeItem(at: originalURL) }

        let image = CapturedImage(name: "scan", fileURL: originalURL, crop: .fullFrame, isDocumentScan: true)
        let exportURL = try DocumentImageProcessor.exportJPEG(
            for: image,
            rotation: .degrees0,
            name: "scaled",
            maxPixelDimension: 80,
            jpegQuality: 0.85
        )
        defer { try? FileManager.default.removeItem(at: exportURL) }

        let exported = try #require(UIImage(contentsOfFile: exportURL.path))
        #expect(exported.size.width <= 80)
        #expect(exported.size.height <= 80)
    }
}
