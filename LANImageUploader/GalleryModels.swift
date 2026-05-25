//
//  GalleryModels.swift
//  LANImageUploader
//

import Foundation
import CoreGraphics
import UIKit
import CoreImage
import ImageIO

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
            && lhs.capturedImage?.name == rhs.capturedImage?.name
            && lhs.capturedImage?.fileURL == rhs.capturedImage?.fileURL
            && lhs.capturedImage?.crop == rhs.capturedImage?.crop
            && lhs.capturedImage?.isDocumentScan == rhs.capturedImage?.isDocumentScan
            && lhs.rotation == rhs.rotation
    }
}

enum DocumentImageProcessor {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func renderedImage(
        for capturedImage: CapturedImage,
        rotation: ImageRotation = .degrees0,
        maxPixelDimension: CGFloat? = nil
    ) -> UIImage? {
        guard let source = CIImage(contentsOf: capturedImage.fileURL, options: [.applyOrientationProperty: true]) else {
            return nil
        }
        return render(
            processedImage(
                source,
                crop: capturedImage.crop,
                rotation: rotation,
                maxPixelDimension: maxPixelDimension
            )
        )
    }

    static func renderedImage(_ source: UIImage, crop: DocumentCrop?, rotation: ImageRotation = .degrees0) -> UIImage {
        guard let ciImage = CIImage(image: source),
              let output = render(processedImage(ciImage, crop: crop, rotation: rotation, maxPixelDimension: nil)) else {
            return source
        }
        return output
    }

    static func exportJPEG(
        for capturedImage: CapturedImage,
        rotation: ImageRotation,
        name: String,
        maxPixelDimension: CGFloat,
        jpegQuality: CGFloat
    ) throws -> URL {
        guard let source = CIImage(contentsOf: capturedImage.fileURL, options: [.applyOrientationProperty: true]),
              let rendered = render(
                processedImage(
                    source,
                    crop: capturedImage.crop,
                    rotation: rotation,
                    maxPixelDimension: maxPixelDimension
                )
              ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let data = rendered.jpegData(compressionQuality: jpegQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)_\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func processedImage(
        _ source: CIImage,
        crop: DocumentCrop?,
        rotation: ImageRotation,
        maxPixelDimension: CGFloat?
    ) -> CIImage {
        var output = crop.flatMap { perspectiveCorrected(source, crop: $0) } ?? source
        output = applyRotation(to: output, rotation: rotation)
        if let maxPixelDimension {
            let largestDimension = max(output.extent.width, output.extent.height)
            if largestDimension > maxPixelDimension {
                let scale = maxPixelDimension / largestDimension
                output = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }
        return translatedToOrigin(output)
    }

    private static func perspectiveCorrected(_ image: CIImage, crop: DocumentCrop) -> CIImage? {
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
        return filter.outputImage
    }

    private static func applyRotation(to image: CIImage, rotation: ImageRotation) -> CIImage {
        switch rotation {
        case .degrees0:
            return image
        case .degrees90:
            return image.oriented(.right)
        case .degrees180:
            return image.oriented(.down)
        case .degrees270:
            return image.oriented(.left)
        }
    }

    private static func translatedToOrigin(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(
            translationX: -image.extent.minX,
            y: -image.extent.minY
        ))
    }

    private static func render(_ image: CIImage) -> UIImage? {
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
