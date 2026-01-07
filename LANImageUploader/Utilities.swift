//
//  Utilities.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

// Utilities.swift
import Foundation

extension String {
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

// Scoped, synchronous locking helper for NSLock.
// This avoids calling lock()/unlock() directly from async contexts.
extension NSLock {
    @inlinable
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

enum LiquidGlassUtils {
    static func calculateRefractionOffset(depth: CGFloat, angle: Double) -> CGSize {
        let radians = angle * .pi / 180.0
        let dx = depth * tan(radians)
        let dy = depth * tan(radians)
        return CGSize(width: dx, height: dy)
    }
}
