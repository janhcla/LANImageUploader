//
//  MockHapticFeedbackService.swift
//  LANImageUploaderTests
//

import Foundation
import UIKit
@testable import LANImageUploader

final class MockHapticFeedbackService: HapticFeedbackServiceProtocol, @unchecked Sendable {
    var playSelectionCalled = false
    func playSelection() {
        playSelectionCalled = true
    }

    var playImpactCalled = false
    var lastImpactStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        playImpactCalled = true
        lastImpactStyle = style
    }

    var playNotificationCalled = false
    var lastNotificationType: UINotificationFeedbackGenerator.FeedbackType?
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        playNotificationCalled = true
        lastNotificationType = type
    }

    var playLiquidBounceCalled = false
    func playLiquidBounce() {
        playLiquidBounceCalled = true
    }
}
