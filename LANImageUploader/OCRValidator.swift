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
    private static let cprRegex = try! NSRegularExpression(pattern: #"(?<!\d)((?:0[1-9]|[12]\d|3[01])(?:0[1-9]|1[0-2])\d{2})-?(\d{4})(?!\d)"#)

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
            
            if let match = cprRegex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) {
                let nsString = normalized as NSString
                let datePart = nsString.substring(with: match.range(at: 1))
                let sequencePart = nsString.substring(with: match.range(at: 2))
                return "\(datePart)-\(sequencePart)"
            }
            
            return nil
        }
    }
}
