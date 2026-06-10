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

enum PDFCompressionLevel: String, CaseIterable, Identifiable, Codable {
    case light
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .light: return 0.80
        case .medium: return 0.60
        case .high: return 0.42
        }
    }

    var maxPixelDimension: CGFloat {
        switch self {
        case .light: return 2500
        case .medium: return 1800
        case .high: return 1200
        }
    }
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
    struct PixelPoints: Equatable {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint
    }

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

    static func visionNormalized(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint
    ) -> DocumentCrop {
        func topLeftOrigin(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1 - point.y)
        }
        return DocumentCrop(
            topLeft: topLeftOrigin(topLeft),
            topRight: topLeftOrigin(topRight),
            bottomRight: topLeftOrigin(bottomRight),
            bottomLeft: topLeftOrigin(bottomLeft)
        )
    }

    func mapped(fromAspectFillImageSize sourceSize: CGSize, toImageSize targetSize: CGSize) -> DocumentCrop? {
        guard sourceSize.width > 0, sourceSize.height > 0,
              targetSize.width > 0, targetSize.height > 0 else {
            return nil
        }
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = targetSize.width / targetSize.height
        let visibleRect: CGRect
        if sourceAspect < targetAspect {
            let width = sourceAspect / targetAspect
            visibleRect = CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        } else {
            let height = targetAspect / sourceAspect
            visibleRect = CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
        }
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: visibleRect.minX + point.x * visibleRect.width,
                y: visibleRect.minY + point.y * visibleRect.height
            )
        }
        return DocumentCrop(
            topLeft: map(topLeft),
            topRight: map(topRight),
            bottomRight: map(bottomRight),
            bottomLeft: map(bottomLeft)
        )
    }

    func isValidForPerspectiveCorrection(
        minArea: CGFloat = 0.08,
        minimumEdgeLength: CGFloat = 0.08,
        boundsEpsilon: CGFloat = 0.002
    ) -> Bool {
        guard points.allSatisfy({
            $0.x.isFinite && $0.y.isFinite
                && $0.x >= -boundsEpsilon && $0.x <= 1 + boundsEpsilon
                && $0.y >= -boundsEpsilon && $0.y <= 1 + boundsEpsilon
        }) else {
            return false
        }

        let ordered = points
        let crossProducts = ordered.indices.map { index -> CGFloat in
            let first = ordered[index]
            let second = ordered[(index + 1) % ordered.count]
            let third = ordered[(index + 2) % ordered.count]
            return (second.x - first.x) * (third.y - second.y)
                - (second.y - first.y) * (third.x - second.x)
        }
        guard crossProducts.allSatisfy({ $0 > 0.0001 }) else { return false }

        let area = zip(ordered, ordered.dropFirst() + [ordered[0]])
            .reduce(CGFloat.zero) { result, pair in
                result + pair.0.x * pair.1.y - pair.1.x * pair.0.y
            } / 2
        guard area >= minArea else { return false }

        func length(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
            hypot(first.x - second.x, first.y - second.y)
        }
        let top = length(topLeft, topRight)
        let right = length(topRight, bottomRight)
        let bottom = length(bottomRight, bottomLeft)
        let left = length(bottomLeft, topLeft)
        guard min(top, right, bottom, left) >= minimumEdgeLength else { return false }
        guard max(top, bottom) / min(top, bottom) < 3,
              max(left, right) / min(left, right) < 3 else {
            return false
        }

        let bounds = boundingRect
        let aspect = bounds.width / bounds.height
        return aspect.isFinite && aspect >= 0.2 && aspect <= 5
    }

    func coreImagePoints(in extent: CGRect) -> PixelPoints {
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.minX + point.x * extent.width,
                y: extent.minY + (1 - point.y) * extent.height
            )
        }
        return PixelPoints(
            topLeft: map(topLeft),
            topRight: map(topRight),
            bottomRight: map(bottomRight),
            bottomLeft: map(bottomLeft)
        )
    }

    private var boundingRect: CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )
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
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 1, extent.height > 1,
              crop.isValidForPerspectiveCorrection() else {
            return nil
        }
        let normalizedCrop = crop.clamped()
        let points = normalizedCrop.coreImagePoints(in: extent)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: points.topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: points.topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: points.bottomRight), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: points.bottomLeft), forKey: "inputBottomLeft")
        guard let output = filter.outputImage,
              isPlausible(output.extent, comparedWith: extent),
              !isMostlyBlack(output) else {
            return nil
        }
        return output
    }

    private static func isPlausible(_ output: CGRect, comparedWith source: CGRect) -> Bool {
        guard output.minX.isFinite, output.minY.isFinite,
              output.width.isFinite, output.height.isFinite,
              output.width > 1, output.height > 1 else {
            return false
        }
        let areaRatio = (output.width * output.height) / (source.width * source.height)
        let aspect = output.width / output.height
        return areaRatio >= 0.01 && areaRatio <= 4
            && aspect >= 0.1 && aspect <= 10
            && max(output.width, output.height) <= max(source.width, source.height) * 4
    }

    private static func isMostlyBlack(_ image: CIImage) -> Bool {
        let sampleSize = 32
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return true }
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        guard let bitmap = CGContext(
            data: &pixels,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return true
        }
        bitmap.interpolationQuality = .low
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        let blackPixels = stride(from: 0, to: pixels.count, by: 4).reduce(into: 0) { count, index in
            let luminance = 0.2126 * Double(pixels[index])
                + 0.7152 * Double(pixels[index + 1])
                + 0.0722 * Double(pixels[index + 2])
            if luminance < 8 {
                count += 1
            }
        }
        return Double(blackPixels) / Double(sampleSize * sampleSize) >= 0.70
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
