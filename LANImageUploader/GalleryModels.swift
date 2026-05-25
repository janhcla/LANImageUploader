//
//  GalleryModels.swift
//  LANImageUploader
//

import Foundation
import CoreGraphics
import UIKit
import CoreImage

enum GalleryOutputMode: String, CaseIterable, Identifiable, Codable {
    case separateImages
    case singlePDF
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .separateImages: return "Separate Images"
        case .singlePDF: return "Single PDF"
        }
    }
}

enum PDFPageSize: String, CaseIterable, Identifiable, Codable {
    case a4
    case letter
    var id: String { rawValue }
    var pageRect: CGRect {
        switch self {
        case .a4:
            // A4 at 72 dpi: 595.2 x 841.8 points
            return CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        case .letter:
            return CGRect(x: 0, y: 0, width: 612, height: 792)
        }
    }
}

enum PDFImageLayout: String, CaseIterable, Identifiable, Codable {
    case fit
    case fill
    var id: String { rawValue }
}

struct PDFSettings: Codable, Equatable {
    var pageSize: PDFPageSize = .a4
    var imageLayout: PDFImageLayout = .fit
    var includePageNumbers: Bool = true
    var jpegQuality: CGFloat = 0.85
    var margin: CGFloat = 24
    var maxPixelDimension: CGFloat = 2500
}

enum ImageRotation: Int, Codable, CaseIterable {
    case degrees0 = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270
    var nextClockwise: ImageRotation {
        switch self {
        case .degrees0: return .degrees90
        case .degrees90: return .degrees180
        case .degrees180: return .degrees270
        case .degrees270: return .degrees0
        }
    }
}

struct DocumentCrop: Codable, Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let fullFrame = DocumentCrop(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1),
        bottomLeft: CGPoint(x: 0, y: 1)
    )

    var points: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    func clamped() -> DocumentCrop {
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        }
        return DocumentCrop(
            topLeft: clamp(topLeft),
            topRight: clamp(topRight),
            bottomRight: clamp(bottomRight),
            bottomLeft: clamp(bottomLeft)
        )
    }
}

struct GalleryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var capturedImage: CapturedImage?
    var rotation: ImageRotation

    static func == (lhs: GalleryItem, rhs: GalleryItem) -> Bool {
        lhs.id == rhs.id
            && lhs.capturedImage?.id == rhs.capturedImage?.id
            && lhs.rotation == rhs.rotation
    }
}

enum DocumentImageProcessor {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func renderedImage(for capturedImage: CapturedImage, rotation: ImageRotation = .degrees0) -> UIImage? {
        guard let source = UIImage(contentsOfFile: capturedImage.fileURL.path) else { return nil }
        return renderedImage(source, crop: capturedImage.crop, rotation: rotation)
    }

    static func renderedImage(_ source: UIImage, crop: DocumentCrop?, rotation: ImageRotation = .degrees0) -> UIImage {
        let normalized = source.normalizedForUpload(maxPixelDimension: nil, jpegQuality: 1)
        let corrected = crop.flatMap { perspectiveCorrected(normalized, crop: $0) } ?? normalized
        return corrected.rotatedClockwise(by: rotation)
    }

    static func exportJPEG(
        for capturedImage: CapturedImage,
        rotation: ImageRotation,
        name: String,
        maxPixelDimension: CGFloat,
        jpegQuality: CGFloat
    ) throws -> URL {
        guard let rendered = renderedImage(for: capturedImage, rotation: rotation) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let uploadImage = rendered.normalizedForUpload(
            maxPixelDimension: maxPixelDimension,
            jpegQuality: jpegQuality
        )
        guard let data = uploadImage.jpegData(compressionQuality: jpegQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)_\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func perspectiveCorrected(_ source: UIImage, crop: DocumentCrop) -> UIImage? {
        guard let image = CIImage(image: source) else { return nil }
        let extent = image.extent
        let normalizedCrop = crop.clamped()
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(
                x: extent.minX + point.x * extent.width,
                y: extent.minY + (1 - point.y) * extent.height
            )
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector(normalizedCrop.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(normalizedCrop.topRight), forKey: "inputTopRight")
        filter.setValue(vector(normalizedCrop.bottomRight), forKey: "inputBottomRight")
        filter.setValue(vector(normalizedCrop.bottomLeft), forKey: "inputBottomLeft")
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
