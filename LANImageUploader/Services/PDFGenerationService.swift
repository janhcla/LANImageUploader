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

        var writer = try LegacyPDFWriter(pageCount: validItems.count, pageRect: settings.pageSize.pageRect, url: fileURL)
        var didFinishWriting = false
        defer {
            writer.close()
            if !didFinishWriting {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

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

                    let page = LegacyPDFWriter.Page(
                        jpeg: jpeg,
                        pixelWidth: cgImage.width,
                        pixelHeight: cgImage.height,
                        drawRect: drawRect,
                        pageNumber: settings.includePageNumbers ? "\(index + 1) / \(validItems.count)" : nil,
                        pageNumberY: max(8, settings.margin / 2)
                    )
                    try writer.writePage(page, index: index)
            }
        }
        try writer.finish()
        didFinishWriting = true
        return fileURL
    }
}

private struct LegacyPDFWriter {
    struct Page {
        let jpeg: Data
        let pixelWidth: Int
        let pixelHeight: Int
        let drawRect: CGRect
        let pageNumber: String?
        let pageNumberY: CGFloat
    }

    private let pageCount: Int
    private let pageRect: CGRect
    private let handle: FileHandle
    private var byteOffset = 0
    private var offsets: [Int] = []

    init(pageCount: Int, pageRect: CGRect, url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        self.pageCount = pageCount
        self.pageRect = pageRect
        self.handle = try FileHandle(forWritingTo: url)

        writeASCII("%PDF-1.3\n%")
        writeData(Data([0xE2, 0xE3, 0xCF, 0xD3]))
        writeASCII("\n")

        let pageIDs = (0..<pageCount).map { Self.pageObjectID(for: $0) }
        writeObject(id: 1, data: ascii("<< /Type /Catalog /Pages 2 0 R >>"))
        writeObject(id: 2, data: ascii("<< /Type /Pages /Count \(pageCount) /Kids [\(pageIDs.map { "\($0) 0 R" }.joined(separator: " "))] /MediaBox [0 0 \(pdfNumber(pageRect.width)) \(pdfNumber(pageRect.height))] >>"))
    }

    mutating func writePage(_ page: Page, index: Int) throws {
        let pageID = Self.pageObjectID(for: index)
        let imageID = pageID + 1
        let contentID = pageID + 2
        writeObject(id: pageID, data: ascii("<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Im0 \(imageID) 0 R >> /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> /Contents \(contentID) 0 R >>"))

        writeObjectHeader(id: imageID)
        writeASCII("<< /Type /XObject /Subtype /Image /Width \(page.pixelWidth) /Height \(page.pixelHeight) /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length \(page.jpeg.count) >>\nstream\n")
        writeData(page.jpeg)
        writeASCII("\nendstream\nendobj\n")

        let r = page.drawRect
        var commands = "q \(pdfNumber(r.width)) 0 0 \(pdfNumber(r.height)) \(pdfNumber(r.minX)) \(pdfNumber(pageRect.height - r.maxY)) cm /Im0 Do Q\n"
        if let number = page.pageNumber {
            let x = pageRect.midX - CGFloat(number.count) * 2.5
            commands += "BT /F1 10 Tf \(pdfNumber(x)) \(pdfNumber(page.pageNumberY)) Td (\(number)) Tj ET\n"
        }
        let content = ascii(commands)
        var stream = ascii("<< /Length \(content.count) >>\nstream\n")
        stream.append(content)
        stream.append(ascii("\nendstream"))
        writeObject(id: contentID, data: stream)
    }

    mutating func finish() throws {
        let xref = byteOffset
        writeASCII("xref\n0 \(offsets.count + 1)\n0000000000 65535 f \n")
        for offset in offsets {
            writeASCII(String(format: "%010d 00000 n \n", locale: Locale(identifier: "en_US_POSIX"), offset))
        }
        writeASCII("trailer\n<< /Size \(offsets.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n")
        try handle.close()
    }

    func close() {
        try? handle.close()
    }

    private static func pageObjectID(for index: Int) -> Int {
        3 + index * 3
    }

    private mutating func writeObject(id: Int, data: Data) {
        writeObjectHeader(id: id)
        writeData(data)
        writeASCII("\nendobj\n")
    }

    private mutating func writeObjectHeader(id: Int) {
        offsets.append(byteOffset)
        writeASCII("\(id) 0 obj\n")
    }

    private mutating func writeASCII(_ value: String) {
        writeData(ascii(value))
    }

    private mutating func writeData(_ data: Data) {
        handle.write(data)
        byteOffset += data.count
    }

    private func ascii(_ value: String) -> Data {
        Data(value.utf8)
    }

    private func pdfNumber(_ value: CGFloat) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
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
