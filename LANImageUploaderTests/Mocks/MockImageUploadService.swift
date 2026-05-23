//
//  MockImageUploadService.swift
//  LANImageUploaderTests
//
//  Created by AI on 06/01/2026.
//

import Foundation
@testable import LANImageUploader

final class MockImageUploadService: ImageUploadServiceProtocol, @unchecked Sendable {
    var uploadError: Error?
    var progressValues: [Double] = [0.5, 1.0]
    var uploadedImages: [CapturedImage] = []
    var uploadedFiles: [UploadableFile] = []
    var overwriteValues: [Bool] = []
    var passwords: [String] = []
    var settingsValues: [ServerSettings] = []

    func upload(
        file: UploadableFile,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        if let error = uploadError {
            throw error
        }

        uploadedFiles.append(file)
        overwriteValues.append(overwrite)
        passwords.append(password)
        settingsValues.append(settings)

        for progress in progressValues {
            onProgress(progress)
        }
    }
    
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        uploadedImages.append(image)
        try await upload(
            file: UploadableFile(id: image.id, name: image.name, fileURL: image.fileURL, kind: .jpeg),
            settings: settings,
            password: password,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }
}
