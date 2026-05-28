import Foundation
@testable import LANImageUploader

final class MockPremiumAccessPersisting: PremiumAccessPersisting {
    var successfulUploadCount: Int = 0
    var hasPurchasedFullUnlock: Bool = false
    var isDeveloperModeEnabled: Bool = false
}
