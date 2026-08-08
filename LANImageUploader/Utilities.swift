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

enum FileNameValidation {
    private static let invalidCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
    private static let reservedBaseNames: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]

    static func issue(for proposedName: String) -> String? {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a name." }
        guard trimmed.count <= 255 else { return "Use a name with 255 characters or fewer." }
        guard trimmed != ".", trimmed != ".." else { return "Choose a more descriptive name." }
        guard trimmed.rangeOfCharacter(from: invalidCharacters) == nil else {
            return "Avoid <, >, :, \", /, \\, |, ?, and *."
        }
        guard trimmed.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            return "Remove control characters from the name."
        }
        guard !trimmed.hasSuffix("."), !trimmed.hasSuffix(" ") else {
            return "Do not end the name with a period or space."
        }

        let baseName = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .uppercased() ?? ""
        guard !reservedBaseNames.contains(baseName) else {
            return "Choose another name; this one is reserved by Windows."
        }
        return nil
    }

    static func isValid(_ proposedName: String) -> Bool {
        issue(for: proposedName) == nil
    }
}
