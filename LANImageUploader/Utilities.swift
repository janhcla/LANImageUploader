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
