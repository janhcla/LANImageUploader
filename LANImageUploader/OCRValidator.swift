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
            
            let dashedPattern = #"\d{6}-\d{4}"#
            if let match = normalized.range(of: dashedPattern, options: .regularExpression) {
                return String(normalized[match])
            }
            
            // Fallback: accept exactly 10 digits and normalize to DDMMYY-XXXX
            let digitsOnly = normalized.filter { $0.isNumber }
            if digitsOnly.count == 10 && normalized.range(of: #"^\d{10}$"#, options: .regularExpression) != nil {
                let prefix = digitsOnly.prefix(6)
                let suffix = digitsOnly.suffix(4)
                return "\(prefix)-\(suffix)"
            }
            
            return nil
        }
    }
}
