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
    let isPremiumOverrideEnabled: Bool
    let canUsePremiumOverride: Bool
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
    var isPremiumOverrideEnabled: Bool { get set }
}

final class PremiumAccessController: ObservableObject {
    private var store: PremiumAccessPersisting
    private let trialUploadLimit: Int
    private var premiumOverrideAllowed: Bool

    @Published private(set) var state: PremiumAccessState

    init(
        store: PremiumAccessPersisting,
        trialUploadLimit: Int = PremiumAccessConstants.trialUploadLimit,
        canUsePremiumOverride: @escaping () -> Bool = AppDistribution.allowsPremiumOverride
    ) {
        self.store = store
        self.trialUploadLimit = trialUploadLimit
        self.premiumOverrideAllowed = canUsePremiumOverride()
        let overrideAllowed = premiumOverrideAllowed
        let overrideEnabled = overrideAllowed && store.isPremiumOverrideEnabled
        self.state = PremiumAccessState(
            isFullAppUnlocked: store.hasPurchasedFullUnlock || overrideEnabled,
            isPremiumOverrideEnabled: overrideEnabled,
            canUsePremiumOverride: overrideAllowed,
            successfulUploadCount: store.successfulUploadCount,
            trialUploadLimit: trialUploadLimit
        )
    }

    func recordSuccessfulUpload() {
        guard !state.isFullAppUnlocked else { return }
        store.successfulUploadCount += 1
        reload()
    }

    func setPremiumOverrideEnabled(_ isEnabled: Bool) {
        guard premiumOverrideAllowed else {
            store.isPremiumOverrideEnabled = false
            reload()
            return
        }
        store.isPremiumOverrideEnabled = isEnabled
        reload()
    }

    func markPurchasedFullUnlock() {
        store.hasPurchasedFullUnlock = true
        reload()
    }

    func reload() {
        let overrideAllowed = premiumOverrideAllowed
        if !overrideAllowed, store.isPremiumOverrideEnabled {
            store.isPremiumOverrideEnabled = false
        }
        let overrideEnabled = overrideAllowed && store.isPremiumOverrideEnabled
        state = PremiumAccessState(
            isFullAppUnlocked: store.hasPurchasedFullUnlock || overrideEnabled,
            isPremiumOverrideEnabled: overrideEnabled,
            canUsePremiumOverride: overrideAllowed,
            successfulUploadCount: store.successfulUploadCount,
            trialUploadLimit: trialUploadLimit
        )
    }

    func refreshPremiumOverrideEligibility(
        canUsePremiumOverride: () -> Bool = AppDistribution.allowsPremiumOverride
    ) {
        premiumOverrideAllowed = canUsePremiumOverride()
        reload()
    }
}

enum AppBuildChannel: String, Equatable {
    case production
    case testFlight
}

enum BuildDistributionChannel {
    // Xcode Cloud's ci_pre_xcodebuild.sh rewrites this before every action.
    // Checked-in source remains production, so a missing or mismatched workflow
    // cannot expose the validation control.
    static let current: AppBuildChannel = .production
}

enum AppDistribution {
    static func allowsPremiumOverride() -> Bool {
        allowsPremiumOverride(
            buildChannel: BuildDistributionChannel.current,
            isDebugBuild: isDebugBuild
        )
    }

    static func allowsPremiumOverride(
        buildChannel: AppBuildChannel,
        isDebugBuild: Bool
    ) -> Bool {
        isDebugBuild || buildChannel == .testFlight
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
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

    var isPremiumOverrideEnabled: Bool {
        get { userDefaults.bool(forKey: Constants.UserDefaults.premiumOverrideEnabled) }
        set { userDefaults.set(newValue, forKey: Constants.UserDefaults.premiumOverrideEnabled) }
    }

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
            kSecReturnData as String: NSNumber(value: true),
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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }

        var addQuery = query
        addQuery[kSecValueData as String] = valueData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
