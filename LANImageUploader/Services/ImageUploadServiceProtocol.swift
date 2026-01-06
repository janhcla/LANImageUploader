//
//  ImageUploadServiceProtocol.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

protocol ImageUploadServiceProtocol: Sendable {
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws
}
