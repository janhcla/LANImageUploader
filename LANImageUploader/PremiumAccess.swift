//
//  PremiumAccess.swift
//  LANImageUploader
//
//  Created by AI on 14/05/2026.
//

import Foundation
import Security

struct PremiumAccessState: Equatable {
    let isFullAppUnlocked: Bool
    let isDeveloperModeEnabled: Bool
    let successfulUploadCount: Int
    let trialUploadLimit: Int

    var remainingTrialUploads: Int {
        max(0, trialUploadLimit - successfulUploadCount)
    }

    var canUpload: Bool {
        isFullAppUnlocked || remainingTrialUploads > 0
    }

    var shouldShowTrialStatus: Bool {
        !isFullAppUnlocked
    }
}

enum PremiumAccessConstants {
    static let fullUnlockProductID = "com.janhagenclausen.LANImageUploader.fullunlock"
    static let fullUnlockPriceDisplay = "USD 1.99"
    static let trialUploadLimit = 15
}

protocol PremiumAccessPersisting {
    var successfulUploadCount: Int { get set }
    var hasPurchasedFullUnlock: Bool { get set }
    var isDeveloperModeEnabled: Bool { get set }
}

final class PremiumAccessController: ObservableObject {
    private var store: PremiumAccessPersisting
    private let trialUploadLimit: Int

    @Published private(set) var state: PremiumAccessState

    init(
        store: PremiumAccessPersisting,
        trialUploadLimit: Int = PremiumAccessConstants.trialUploadLimit
    ) {
        self.store = store
        self.trialUploadLimit = trialUploadLimit
        #if DEBUG
        let developerModeEnabled = store.isDeveloperModeEnabled
        #else
        let developerModeEnabled = false
        #endif
        self.state = PremiumAccessState(
            isFullAppUnlocked: store.hasPurchasedFullUnlock || developerModeEnabled,
            isDeveloperModeEnabled: developerModeEnabled,
            successfulUploadCount: store.successfulUploadCount,
            trialUploadLimit: trialUploadLimit
        )
    }

    func recordSuccessfulUpload() {
        guard !state.isFullAppUnlocked else { return }
        store.successfulUploadCount += 1
        reload()
    }

    #if DEBUG
    func setDeveloperModeEnabled(_ isEnabled: Bool) {
        store.isDeveloperModeEnabled = isEnabled
        reload()
    }
    #endif

    func markPurchasedFullUnlock() {
        store.hasPurchasedFullUnlock = true
        reload()
    }

    func reload() {
        #if DEBUG
        let developerModeEnabled = store.isDeveloperModeEnabled
        #else
        let developerModeEnabled = false
        #endif
        state = PremiumAccessState(
            isFullAppUnlocked: store.hasPurchasedFullUnlock || developerModeEnabled,
            isDeveloperModeEnabled: developerModeEnabled,
            successfulUploadCount: store.successfulUploadCount,
            trialUploadLimit: trialUploadLimit
        )
    }
}

final class KeychainPremiumAccessStore: PremiumAccessPersisting {
    private let service = "com.janhagenclausen.LANImageUploader.premium"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var successfulUploadCount: Int {
        get { intValue(for: Constants.Keychain.premiumSuccessfulUploadCount) }
        set { setString(String(max(0, newValue)), for: Constants.Keychain.premiumSuccessfulUploadCount) }
    }

    var hasPurchasedFullUnlock: Bool {
        get { boolValue(for: Constants.Keychain.premiumFullUnlockPurchased) }
        set { setString(newValue ? "true" : "false", for: Constants.Keychain.premiumFullUnlockPurchased) }
    }

    #if DEBUG
    var isDeveloperModeEnabled: Bool {
        get { userDefaults.bool(forKey: Constants.UserDefaults.developerModeEnabled) }
        set { userDefaults.set(newValue, forKey: Constants.UserDefaults.developerModeEnabled) }
    }
    #else
    var isDeveloperModeEnabled: Bool {
        get { false }
        set { }
    }
    #endif

    private func intValue(for account: String) -> Int {
        guard let value = stringValue(for: account), let intValue = Int(value) else { return 0 }
        return max(0, intValue)
    }

    private func boolValue(for account: String) -> Bool {
        stringValue(for: account) == "true"
    }

    private func stringValue(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func setString(_ value: String, for account: String) {
        let valueData = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }

        var addQuery = query
        addQuery[kSecValueData as String] = valueData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
