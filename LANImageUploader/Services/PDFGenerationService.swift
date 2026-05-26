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
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .noImages: return "There are no images to include in the PDF."
            case .contextFailed: return "Failed to initialize PDF context."
            case .compressionFailed: return "Failed to compress a document page for PDF output."
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

        var failedToCompressPage = false
        try renderer.writePDF(to: fileURL) { context in
            for (index, item) in validItems.enumerated() {
                autoreleasepool {
                    guard let correctedImage = DocumentImageProcessor.renderedImage(
                        for: item.0,
                        rotation: item.1,
                        maxPixelDimension: settings.maxPixelDimension
                    ),
                    let compressedData = correctedImage.jpegData(compressionQuality: settings.jpegQuality),
                    let embeddedImage = UIImage(data: compressedData) else {
                        failedToCompressPage = true
                        return
                    }

                    context.beginPage()
                    let pageRect = settings.pageSize.pageRect

                    let imageAspectRatio = embeddedImage.size.width / embeddedImage.size.height
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

                    embeddedImage.draw(in: drawRect)

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
        if failedToCompressPage {
            try? FileManager.default.removeItem(at: fileURL)
            throw PDFError.compressionFailed
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

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func rotatedClockwise(by rotation: ImageRotation) -> UIImage {
        if rotation == .degrees0 { return self }

        let radians = CGFloat(rotation.rawValue) * .pi / 180
        var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }
}
