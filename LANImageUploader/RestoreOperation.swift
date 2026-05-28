//
//  RestoreOperation.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

struct RestoreOperation: Sendable {
    let source: URL
    let destination: URL
}

struct RestorationResult: Sendable {
    let successCount: Int
    let failureCount: Int
    let restoredImages: [CapturedImage]
}
