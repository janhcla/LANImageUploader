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
    
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        if let error = uploadError {
            throw error
        }
        
        for progress in progressValues {
            onProgress(progress)
        }
    }
}
