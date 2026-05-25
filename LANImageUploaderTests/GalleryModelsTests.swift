//
//  GalleryModelsTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
import UIKit
@testable import LANImageUploader

struct GalleryModelsTests {

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
}
