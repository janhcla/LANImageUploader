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
        static let premiumSuccessfulUploadCount = "premiumSuccessfulUploadCount"
        static let premiumFullUnlockPurchased = "premiumFullUnlockPurchased"
    }
    
    enum UserDefaults {
        static let serverSettings = "serverSettings"
        static let onboardingCompleted = "onboardingCompleted"
        static let archiveCustomNames = "archiveCustomNames"
        static let ocrMode = "ocrMode"
        static let developerModeEnabled = "developerModeEnabled"
    }
    
    enum Notifications {
        static let networkStatusChanged = "NetworkMonitorStateChanged"
        static let archivedImageDeleted = "ArchivedImageDeleted"
    }
    
    enum BackgroundTasks {
        static let dailyImageSave = "com.janhagenclausen.LANImageUploader.dailyImageSave"
    }
}
