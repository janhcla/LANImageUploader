//
//  Constants.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

enum Constants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.janhagenclausen.LANImageUploader"

    enum Keychain {
        static let serverPassword = "serverPassword"
        static let premiumSuccessfulUploadCount = "premiumSuccessfulUploadCount"
        static let premiumFullUnlockPurchased = "premiumFullUnlockPurchased"
    }
    
    enum UserDefaults {
        static let serverSettings = "serverSettings"
        static let onboardingCompleted = "onboardingCompleted"
        static let archiveCustomNames = "archiveCustomNames"
        static let ocrMode = "ocrMode"
        static let premiumOverrideEnabled = "developerModeEnabled"

        // Gallery & PDF Settings
        static let defaultGalleryOutputMode = "defaultGalleryOutputMode"
        static let pdfPageSize = "pdfPageSize"
        static let pdfImageLayout = "pdfImageLayout"
        static let pdfIncludePageNumbers = "pdfIncludePageNumbers"
        static let pdfJPEGQuality = "pdfJPEGQuality"
        static let pdfCompressionLevel = "pdfCompressionLevel"
        static let imageMaxPixelDimension = "imageMaxPixelDimension"
        static let stripImageMetadata = "stripImageMetadata"
        static let capturedImageQueue = "capturedImageQueue"
        static let scannerAutoCaptureEnabled = "scannerAutoCaptureEnabled"
    }
    
    enum Notifications {
        static let networkStatusChanged = "NetworkMonitorStateChanged"
        static let archivedImageDeleted = "ArchivedImageDeleted"
    }
    
    enum BackgroundTasks {
        static let dailyImageSave = "com.janhagenclausen.LANImageUploader.dailyImageSave"
    }
}
