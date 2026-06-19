//
//  PDFGenerationService.swift
//  LANImageUploader
//

import Foundation
import UIKit

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

        let tempDir = FileManager.default.temporaryDirectory
        var safeName = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
        if safeName.isEmpty { safeName = "PDF" }
        safeName = safeName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        let fileURL = tempDir.appendingPathComponent("\(safeName)_\(UUID().uuidString).pdf")

        var pages: [LegacyPDFWriter.Page] = []
        for (index, item) in validItems.enumerated() {
            try autoreleasepool {
                guard let correctedImage = DocumentImageProcessor.renderedImage(
                        for: item.0,
                        rotation: item.1,
                        maxPixelDimension: settings.maxPixelDimension
                    ),
                    let jpeg = correctedImage.jpegData(compressionQuality: settings.jpegQuality),
                    let cgImage = correctedImage.cgImage else {
                        throw PDFError.compressionFailed
                    }
                    let pageRect = settings.pageSize.pageRect
                    let imageAspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
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

                    pages.append(.init(jpeg: jpeg, pixelWidth: cgImage.width, pixelHeight: cgImage.height,
                                       drawRect: drawRect, pageNumber: settings.includePageNumbers ? "\(index + 1) / \(validItems.count)" : nil))
            }
        }
        try LegacyPDFWriter.write(pages: pages, pageRect: settings.pageSize.pageRect, to: fileURL)
        return fileURL
    }
}

private enum LegacyPDFWriter {
    struct Page { let jpeg: Data; let pixelWidth: Int; let pixelHeight: Int; let drawRect: CGRect; let pageNumber: String? }

    static func write(pages: [Page], pageRect: CGRect, to url: URL) throws {
        var objects: [Data] = []
        func ascii(_ value: String) -> Data { Data(value.utf8) }
        let pageIDs = pages.indices.map { 3 + $0 * 3 }
        objects.append(ascii("<< /Type /Catalog /Pages 2 0 R >>"))
        objects.append(ascii("<< /Type /Pages /Count \(pages.count) /Kids [\(pageIDs.map { "\($0) 0 R" }.joined(separator: " "))] /MediaBox [0 0 \(pageRect.width) \(pageRect.height)] >>"))

        for (index, page) in pages.enumerated() {
            let pageID = pageIDs[index], imageID = pageID + 1, contentID = pageID + 2
            objects.append(ascii("<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Im0 \(imageID) 0 R >> /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> /Contents \(contentID) 0 R >>"))
            var image = ascii("<< /Type /XObject /Subtype /Image /Width \(page.pixelWidth) /Height \(page.pixelHeight) /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length \(page.jpeg.count) >>\nstream\n")
            image.append(page.jpeg); image.append(ascii("\nendstream")); objects.append(image)
            let r = page.drawRect
            var commands = "q \(r.width) 0 0 \(r.height) \(r.minX) \(pageRect.height - r.maxY) cm /Im0 Do Q\n"
            if let number = page.pageNumber {
                let x = pageRect.midX - CGFloat(number.count) * 2.5
                commands += "BT /F1 10 Tf \(x) \(max(8, pageRect.height - r.maxY - 18)) Td (\(number)) Tj ET\n"
            }
            let content = ascii(commands)
            var stream = ascii("<< /Length \(content.count) >>\nstream\n")
            stream.append(content)
            stream.append(ascii("\nendstream"))
            objects.append(stream)
        }
        var result = ascii("%PDF-1.3\n%")
        result.append(contentsOf: [0xE2, 0xE3, 0xCF, 0xD3])
        result.append(ascii("\n"))
        var offsets = [0]
        for (index, object) in objects.enumerated() {
            offsets.append(result.count); result.append(ascii("\(index + 1) 0 obj\n")); result.append(object); result.append(ascii("\nendobj\n"))
        }
        let xref = result.count
        result.append(ascii("xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"))
        for offset in offsets.dropFirst() {
            result.append(ascii(String(format: "%010d 00000 n \n", locale: Locale(identifier: "en_US_POSIX"), offset)))
        }
        result.append(ascii("trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"))
        try result.write(to: url, options: .atomic)
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
