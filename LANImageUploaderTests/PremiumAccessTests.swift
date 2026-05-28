//
//  PremiumAccessTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct PremiumAccessTests {

    @Test @MainActor func testInitialStateNotPurchased() async throws {
        let mockStore = MockPremiumAccessPersisting()
        mockStore.successfulUploadCount = 5
        mockStore.hasPurchasedFullUnlock = false
        mockStore.isDeveloperModeEnabled = false

        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.isFullAppUnlocked == false)
        #expect(controller.state.successfulUploadCount == 5)
        #expect(controller.state.trialUploadLimit == 15)
        #expect(controller.state.remainingTrialUploads == 10)
        #expect(controller.state.canUpload == true)
        #expect(controller.state.shouldShowTrialStatus == true)
    }

    @Test @MainActor func testInitialStatePurchased() async throws {
        let mockStore = MockPremiumAccessPersisting()
        mockStore.successfulUploadCount = 20
        mockStore.hasPurchasedFullUnlock = true
        mockStore.isDeveloperModeEnabled = false

        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.isFullAppUnlocked == true)
        #expect(controller.state.successfulUploadCount == 20)
        #expect(controller.state.remainingTrialUploads == 0)
        #expect(controller.state.canUpload == true)
        #expect(controller.state.shouldShowTrialStatus == false)
    }

    @Test @MainActor func testRecordSuccessfulUploadIncrementsCount() async throws {
        let mockStore = MockPremiumAccessPersisting()
        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.successfulUploadCount == 0)
        #expect(controller.state.remainingTrialUploads == 15)

        controller.recordSuccessfulUpload()

        #expect(mockStore.successfulUploadCount == 1)
        #expect(controller.state.successfulUploadCount == 1)
        #expect(controller.state.remainingTrialUploads == 14)
    }

    @Test @MainActor func testRecordSuccessfulUploadDoesNotIncrementWhenPurchased() async throws {
        let mockStore = MockPremiumAccessPersisting()
        mockStore.hasPurchasedFullUnlock = true
        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.successfulUploadCount == 0)

        controller.recordSuccessfulUpload()

        #expect(mockStore.successfulUploadCount == 0)
        #expect(controller.state.successfulUploadCount == 0)
    }

    @Test @MainActor func testMarkPurchasedFullUnlock() async throws {
        let mockStore = MockPremiumAccessPersisting()
        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.isFullAppUnlocked == false)
        #expect(mockStore.hasPurchasedFullUnlock == false)

        controller.markPurchasedFullUnlock()

        #expect(mockStore.hasPurchasedFullUnlock == true)
        #expect(controller.state.isFullAppUnlocked == true)
        #expect(controller.state.shouldShowTrialStatus == false)
    }

    @Test @MainActor func testTrialLimitExceeded() async throws {
        let mockStore = MockPremiumAccessPersisting()
        mockStore.successfulUploadCount = 15
        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.remainingTrialUploads == 0)
        #expect(controller.state.canUpload == false)

        mockStore.successfulUploadCount = 20
        controller.reload()

        #expect(controller.state.remainingTrialUploads == 0)
        #expect(controller.state.canUpload == false)
    }

    #if DEBUG
    @Test @MainActor func testDeveloperModeUnlocksApp() async throws {
        let mockStore = MockPremiumAccessPersisting()
        mockStore.isDeveloperModeEnabled = false
        let controller = PremiumAccessController(store: mockStore, trialUploadLimit: 15)

        #expect(controller.state.isFullAppUnlocked == false)

        controller.setDeveloperModeEnabled(true)

        #expect(mockStore.isDeveloperModeEnabled == true)
        #expect(controller.state.isFullAppUnlocked == true)
        #expect(controller.state.isDeveloperModeEnabled == true)

        // Developer mode should allow uploading even if count exceeded
        mockStore.successfulUploadCount = 20
        controller.reload()
        #expect(controller.state.canUpload == true)
    }
    #endif
}
