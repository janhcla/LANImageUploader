//
//  ImageUploadServiceProtocol.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

protocol ImageUploadServiceProtocol: Sendable {
    func upload(
        file: UploadableFile,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws

    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws
}

extension ImageUploadServiceProtocol {
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await upload(
            file: UploadableFile(
                id: image.id,
                name: image.name,
                fileURL: image.fileURL,
                kind: .jpeg
            ),
            settings: settings,
            password: password,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }
}
