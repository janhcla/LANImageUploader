//
//  Constants.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

enum Constants {
    enum Keychain {
        static let serverPassword = "serverPassword"
    }
    
    enum UserDefaults {
        static let serverSettings = "serverSettings"
        static let onboardingCompleted = "onboardingCompleted"
        static let archiveCustomNames = "archiveCustomNames"
        static let ocrMode = "ocrMode"

        // Gallery & PDF Settings
        static let defaultGalleryOutputMode = "defaultGalleryOutputMode"
        static let pdfPageSize = "pdfPageSize"
        static let pdfImageLayout = "pdfImageLayout"
        static let pdfIncludePageNumbers = "pdfIncludePageNumbers"
        static let pdfJPEGQuality = "pdfJPEGQuality"
        static let imageMaxPixelDimension = "imageMaxPixelDimension"
        static let stripImageMetadata = "stripImageMetadata"
    }
    
    enum Notifications {
        static let networkStatusChanged = "NetworkMonitorStateChanged"
        static let archivedImageDeleted = "ArchivedImageDeleted"
    }
    
    enum BackgroundTasks {
        static let dailyImageSave = "com.janhagenclausen.LANImageUploader.dailyImageSave"
    }
}
