//
//  GalleryModels.swift
//  LANImageUploader
//

import Foundation
import CoreGraphics

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
