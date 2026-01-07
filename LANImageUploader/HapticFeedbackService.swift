//
//  HapticFeedbackService.swift
//  LANImageUploader
//

import UIKit

protocol HapticFeedbackServiceProtocol {
    func playSelection()
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle)
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType)
    func playLiquidBounce()
}

class HapticFeedbackService: HapticFeedbackServiceProtocol {
    static let shared = HapticFeedbackService()
    
    private init() {}
    
    func playSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func playLiquidBounce() {
        // Custom haptic pattern for liquid feel: light impact followed by subtle selection
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }
}
