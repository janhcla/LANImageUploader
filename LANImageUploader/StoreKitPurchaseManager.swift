//
//  StoreKitPurchaseManager.swift
//  LANImageUploader
//
//  Created by AI on 14/05/2026.
//

import Foundation
import StoreKit

enum PurchaseRestorationStatus: Equatable {
    case restored
    case noRestorablePurchase
    case failed(String)

    var message: String {
        switch self {
        case .restored:
            return "Full App Unlock has been restored."
        case .noRestorablePurchase:
            return "No previous Full App Unlock purchase was found for this Apple Account."
        case .failed(let message):
            return "Unable to restore purchases: \(message)"
        }
    }

    var isError: Bool {
        switch self {
        case .restored:
            return false
        case .noRestorablePurchase, .failed:
            return true
        }
    }
}

@MainActor
final class StoreKitPurchaseManager: ObservableObject {
    @Published private(set) var fullUnlockProduct: Product?
    @Published private(set) var purchaseErrorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var restorationStatus: PurchaseRestorationStatus?

    private let restorePurchasesAction: @MainActor () async throws -> Bool
    private let entitlementRefreshAction: @MainActor () async -> Bool
    private let transactionUpdatesAction: @MainActor () -> AsyncStream<Void>
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        restorePurchasesAction: @escaping @MainActor () async throws -> Bool = StoreKitPurchaseManager.restoreFullUnlockEntitlement,
        entitlementRefreshAction: @escaping @MainActor () async -> Bool = StoreKitPurchaseManager.hasFullUnlockEntitlement,
        transactionUpdatesAction: @escaping @MainActor () -> AsyncStream<Void> = StoreKitPurchaseManager.fullUnlockTransactionUpdates
    ) {
        self.restorePurchasesAction = restorePurchasesAction
        self.entitlementRefreshAction = entitlementRefreshAction
        self.transactionUpdatesAction = transactionUpdatesAction
    }

    func loadFullUnlockProduct() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [PremiumAccessConstants.fullUnlockProductID])
            fullUnlockProduct = products.first
            purchaseErrorMessage = nil
        } catch {
            purchaseErrorMessage = "Unable to load purchase information: \(error.localizedDescription)"
        }
    }

    func purchaseFullUnlock(accessController: PremiumAccessController) async {
        guard !isPurchasing, !isRestoring else { return }

        if fullUnlockProduct == nil {
            await loadFullUnlockProduct()
        }
        guard let product = fullUnlockProduct else {
            purchaseErrorMessage = "Full App Unlock is not available right now."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                accessController.markPurchasedFullUnlock()
                await transaction.finish()
                purchaseErrorMessage = nil
            case .pending:
                purchaseErrorMessage = "Purchase is pending approval."
            case .userCancelled:
                purchaseErrorMessage = nil
            @unknown default:
                purchaseErrorMessage = "Purchase could not be completed."
            }
        } catch {
            purchaseErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func syncPurchasedEntitlements(accessController: PremiumAccessController) async {
        if await entitlementRefreshAction() {
            accessController.markPurchasedFullUnlock()
        }
    }

    /// Listens for purchases and promo codes redeemed outside the purchase view.
    func startObservingTransactionUpdates(accessController: PremiumAccessController) {
        guard transactionUpdatesTask == nil else { return }

        let transactionUpdates = transactionUpdatesAction()
        transactionUpdatesTask = Task { [weak accessController] in
            for await _ in transactionUpdates {
                guard let accessController else { break }
                accessController.markPurchasedFullUnlock()
            }
        }
    }

    func restorePurchases(accessController: PremiumAccessController) async {
        guard !isPurchasing, !isRestoring else { return }

        isRestoring = true
        restorationStatus = nil
        defer { isRestoring = false }

        do {
            guard try await restorePurchasesAction() else {
                restorationStatus = .noRestorablePurchase
                return
            }

            accessController.markPurchasedFullUnlock()
            restorationStatus = .restored
        } catch {
            restorationStatus = .failed(error.localizedDescription)
        }
    }

    private static func restoreFullUnlockEntitlement() async throws -> Bool {
        try await AppStore.sync()

        return await hasFullUnlockEntitlement()
    }

    private static func hasFullUnlockEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.productID == PremiumAccessConstants.fullUnlockProductID else {
                continue
            }
            return true
        }

        return false
    }

    private static func fullUnlockTransactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard let transaction = try? checkVerified(result),
                          transaction.productID == PremiumAccessConstants.fullUnlockProductID else {
                        continue
                    }

                    await transaction.finish()
                    continuation.yield()
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        }
    }
}
