//
//  PremiumAccess.swift
//  LANImageUploader
//
//  Created by AI on 14/05/2026.
//

import Foundation
import Security
import StoreKit

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
        environmentProvider: @escaping AppDistribution.AppTransactionEnvironmentProvider = AppDistribution.currentAppTransactionEnvironment
    ) async {
        let isAllowed = await AppDistribution.resolvePremiumOverrideEligibility(
            environmentProvider: environmentProvider
        )
        await MainActor.run {
            self.premiumOverrideAllowed = isAllowed
            self.reload()
        }
    }
}

enum AppDistribution {
    typealias AppTransactionEnvironmentProvider = () async throws -> AppStore.Environment

    // Eligibility is resolved asynchronously from StoreKit at launch. Keep the
    // synchronous default fail-closed until AppTransaction.shared has been
    // verified, so a production build can never expose the validation control
    // merely because of a stale flag or build setting.
    static func allowsPremiumOverride() -> Bool {
        return false
    }

    static func resolvePremiumOverrideEligibility(
        environmentProvider: @escaping AppTransactionEnvironmentProvider = currentAppTransactionEnvironment
    ) async -> Bool {
        do {
            let environment = try await environmentProvider()
            // TestFlight transactions are signed by StoreKit's sandbox
            // environment. A production App Store transaction is deliberately
            // excluded, even when the app was previously installed through
            // TestFlight on the same device.
            return environment == .sandbox
        } catch {
            // An unavailable or unverified app transaction is not evidence that
            // the app came from TestFlight. Fail closed in that case.
            return false
        }
    }

    static func currentAppTransactionEnvironment() async throws -> AppStore.Environment {
        let verification = try await AppTransaction.shared
        switch verification {
        case .verified(let transaction):
            return transaction.environment
        case .unverified:
            throw AppDistributionError.unverifiedAppTransaction
        }
    }

    private enum AppDistributionError: Error {
        case unverifiedAppTransaction
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
