//
//  PDFGenerationServiceProtocol.swift
//  LANImageUploader
//

import Foundation

protocol PDFGenerationServiceProtocol: Sendable {
    func generatePDF(
        from items: [GalleryItem],
        outputName: String,
        settings: PDFSettings
    ) async throws -> URL
}
