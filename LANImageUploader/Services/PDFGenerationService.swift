//
//  PDFGenerationService.swift
//  LANImageUploader
//

import Foundation
import UIKit
import PDFKit

final class PDFGenerationService: PDFGenerationServiceProtocol {
    static let shared = PDFGenerationService()

    private init() {}

    enum PDFError: LocalizedError {
        case noImages
        case contextFailed

        var errorDescription: String? {
            switch self {
            case .noImages: return "There are no images to include in the PDF."
            case .contextFailed: return "Failed to initialize PDF context."
            }
        }
    }

    func generatePDF(from items: [GalleryItem], outputName: String, settings: PDFSettings) async throws -> URL {
        let validItems = items.compactMap { item -> (CapturedImage, ImageRotation)? in
            guard let image = item.capturedImage else { return nil }
            return (image, item.rotation)
        }

        guard !validItems.isEmpty else {
            throw PDFError.noImages
        }

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: settings.pageSize.pageRect, format: format)

        let tempDir = FileManager.default.temporaryDirectory
        var safeName = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
        if safeName.isEmpty { safeName = "PDF" }
        safeName = safeName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        let fileURL = tempDir.appendingPathComponent("\(safeName)_\(UUID().uuidString).pdf")

        try renderer.writePDF(to: fileURL) { context in
            for (index, item) in validItems.enumerated() {
                autoreleasepool {
                    let imagePath = item.0.fileURL.path
                    guard let rawImage = UIImage(contentsOfFile: imagePath) else { return }

                    // First, fix the EXIF orientation
                    let normalizedImage = rawImage.normalizedForUpload(maxPixelDimension: settings.maxPixelDimension, jpegQuality: settings.jpegQuality)

                    // Apply user's rotation
                    let rotatedImage = normalizedImage.rotatedClockwise(by: item.1)

                    context.beginPage()
                    let pageRect = settings.pageSize.pageRect

                    let imageAspectRatio = rotatedImage.size.width / rotatedImage.size.height
                    let pageContentRect = pageRect.insetBy(dx: settings.margin, dy: settings.margin)
                    let pageAspectRatio = pageContentRect.width / pageContentRect.height

                    var drawRect: CGRect

                    switch settings.imageLayout {
                    case .fit:
                        if imageAspectRatio > pageAspectRatio {
                            let drawHeight = pageContentRect.width / imageAspectRatio
                            drawRect = CGRect(
                                x: pageContentRect.minX,
                                y: pageContentRect.minY + (pageContentRect.height - drawHeight) / 2,
                                width: pageContentRect.width,
                                height: drawHeight
                            )
                        } else {
                            let drawWidth = pageContentRect.height * imageAspectRatio
                            drawRect = CGRect(
                                x: pageContentRect.minX + (pageContentRect.width - drawWidth) / 2,
                                y: pageContentRect.minY,
                                width: drawWidth,
                                height: pageContentRect.height
                            )
                        }
                    case .fill:
                        drawRect = pageContentRect
                    }

                    rotatedImage.draw(in: drawRect)

                    if settings.includePageNumbers {
                        let pageNumberText = "\(index + 1) / \(validItems.count)"
                        let font = UIFont.systemFont(ofSize: 10)
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: UIColor.black
                        ]

                        let textSize = pageNumberText.size(withAttributes: attributes)
                        let textRect = CGRect(
                            x: pageRect.midX - textSize.width / 2,
                            y: pageRect.maxY - settings.margin / 2 - textSize.height,
                            width: textSize.width,
                            height: textSize.height
                        )
                        pageNumberText.draw(in: textRect, withAttributes: attributes)
                    }
                }
            }
        }

        return fileURL
    }
}

extension UIImage {
    func normalizedForUpload(maxPixelDimension: CGFloat?, jpegQuality: CGFloat) -> UIImage {
        let maxDim = maxPixelDimension ?? max(size.width, size.height)
        var newSize = size

        if size.width > maxDim || size.height > maxDim {
            let ratio = maxDim / max(size.width, size.height)
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return normalizedImage
    }

    func rotatedClockwise(by rotation: ImageRotation) -> UIImage {
        if rotation == .degrees0 { return self }

        let radians = CGFloat(rotation.rawValue) * .pi / 180
        var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return rotatedImage
    }
}
