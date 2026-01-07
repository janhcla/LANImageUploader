//
//  OCRValidator.swift
//  LANImageUploader
//

import Foundation

enum OCRValidator {
    static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out empty or whitespace-only strings
        guard !trimmed.isEmpty else { return false }
        
        // Filter out very short strings (noise)
        guard trimmed.count > 1 else { return false }
        
        // Allow alphanumeric characters and standard punctuation
        // We can refine this regex based on specific requirements later
        return true
    }
}
