//
//  OCRValidator.swift
//  LANImageUploader
//

import Foundation
import OSLog

enum OCRMode: String, CaseIterable, Identifiable {
    case full
    case numbers
    case cpr
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .full:
            return "Full"
        case .numbers:
            return "Numbers"
        case .cpr:
            return "CPR"
        }
    }
}

enum OCRValidator {
    private static let logger = Logger(subsystem: Constants.bundleIdentifier, category: "OCRValidator")

    private static func isValidDate(_ dateString: Substring) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        // Strict parsing so "310224" (Feb 31) fails
        formatter.isLenient = false

        if let _ = formatter.date(from: String(dateString)) {
            return true
        }
        return false
    }

    static func sanitizedText(from text: String, mode: OCRMode) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        switch mode {
        case .full:
            guard trimmed.count > 1 else { return nil }
            return trimmed
        case .numbers:
            let digitsOnly = trimmed.filter { $0.isNumber }
            return digitsOnly.isEmpty ? nil : digitsOnly
        case .cpr:
            // Normalize whitespace and common dash variants before matching
            let noWhitespace = trimmed.replacingOccurrences(
                of: #"\s+"#,
                with: "",
                options: .regularExpression
            )
            let normalized = noWhitespace.replacingOccurrences(
                of: #"[‐‑‒–—−]"#,
                with: "-",
                options: .regularExpression
            )
            
            do {
                let pattern = #"(^|\D)((?:0[1-9]|[12]\d|3[01])(?:0[1-9]|1[0-2])\d{2})-?(\d{4})(\D|$)"#
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
                let matches = regex.matches(in: normalized, range: range)

                for match in matches {
                    guard match.numberOfRanges >= 4,
                          let dateRange = Range(match.range(at: 2), in: normalized),
                          let sequenceRange = Range(match.range(at: 3), in: normalized)
                    else { continue }

                    let date = normalized[dateRange]
                    guard isValidDate(date) else { continue }
                    return "\(date)-\(normalized[sequenceRange])"
                }
            } catch {
                logger.error("Regex matching failed: \(error.localizedDescription, privacy: .private)")
            }
            return nil
        }
    }
}
