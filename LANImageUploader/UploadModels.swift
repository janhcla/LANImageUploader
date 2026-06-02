//
//  UploadModels.swift
//  LANImageUploader
//

import Foundation

enum UploadFileKind: String, Codable, Sendable {
    case jpeg
    case pdf
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .pdf: return "pdf"
        }
    }
    var displayName: String {
        switch self {
        case .jpeg: return "Image"
        case .pdf: return "PDF"
        }
    }
}

struct UploadableFile: Identifiable, Sendable {
    let id: UUID
    var name: String
    var fileURL: URL
    var kind: UploadFileKind
    var sourceImageIDs: Set<UUID> = []
}
