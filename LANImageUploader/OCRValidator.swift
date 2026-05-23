//
//  OCRValidator.swift
//  LANImageUploader
//

import Foundation

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
    // Matches a valid DDMMYY date format and a 4-digit sequence, optionally separated by a dash.
    // DD: 01-31, MM: 01-12, YY: 00-99
    // Negative lookbehind and lookahead prevent matching inside longer digit sequences.
    @available(iOS 16.0, *)
    private static let cprRegex = /(?<!\d)(?<date>(?:0[1-9]|[12]\d|3[01])(?:0[1-9]|1[0-2])\d{2})-?(?<sequence>\d{4})(?!\d)/

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
            
            if #available(iOS 16.0, *) {
                if let match = try? cprRegex.firstMatch(in: normalized) {
                    return "\(match.date)-\(match.sequence)"
                }
            } else {
                // Fallback for older iOS versions if necessary. In this project iOS 18 is assumed based on the PR comment.
            }
            
            return nil
        }
    }
}
