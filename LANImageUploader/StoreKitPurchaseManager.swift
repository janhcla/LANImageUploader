//
//  StoreKitPurchaseManager.swift
//  LANImageUploader
//
//  Created by AI on 14/05/2026.
//

import Foundation
import StoreKit

@MainActor
final class StoreKitPurchaseManager: ObservableObject {
    @Published private(set) var fullUnlockProduct: Product?
    @Published private(set) var purchaseErrorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false

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
                let transaction = try checkVerified(verification)
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
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.productID == PremiumAccessConstants.fullUnlockProductID else {
                continue
            }
            accessController.markPurchasedFullUnlock()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        }
    }
}
