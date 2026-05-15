//
//  FullAppUnlockView.swift
//  LANImageUploader
//
//  Created by AI on 14/05/2026.
//

import SwiftUI

struct FullAppUnlockView: View {
    @EnvironmentObject var appData: AppData
    @StateObject private var purchaseManager = StoreKitPurchaseManager()

    private var displayedPrice: String {
        purchaseManager.fullUnlockProduct?.displayPrice ?? PremiumAccessConstants.fullUnlockPriceDisplay
    }

    var body: some View {
        Form {
            Section("Full App Unlock") {
                Text("Unlock unlimited successful file uploads to your server.")
                Text("One-time purchase: \(displayedPrice)")
                    .font(.headline)

                if appData.premiumAccess.state.isFullAppUnlocked {
                    Label("Full App Unlock is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(appData.premiumAccess.state.remainingTrialUploads) trial uploads remaining")
                        .foregroundStyle(appData.premiumAccess.state.canUpload ? Color.secondary : Color.red)

                    Button {
                        Task {
                            await purchaseManager.purchaseFullUnlock(accessController: appData.premiumAccess)
                        }
                    } label: {
                        if purchaseManager.isPurchasing {
                            ProgressView()
                        } else {
                            Text("Unlock for \(displayedPrice)")
                        }
                    }
                    .disabled(purchaseManager.isLoading || purchaseManager.isPurchasing)
                }
            }

            if let error = purchaseManager.purchaseErrorMessage {
                Section("Purchase Status") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Full App Unlock")
        .task {
            await purchaseManager.loadFullUnlockProduct()
            await purchaseManager.syncPurchasedEntitlements(accessController: appData.premiumAccess)
        }
    }
}

#Preview {
    NavigationStack {
        FullAppUnlockView()
            .environmentObject(AppData.preview)
    }
}
