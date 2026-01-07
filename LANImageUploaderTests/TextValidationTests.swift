//
//  TextValidationTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct TextValidationTests {

    @Test func testTextValidationLogic() {
        // Test valid cases
        #expect(OCRValidator.isValid("Valid Name"))
        #expect(OCRValidator.isValid("Image 123"))
        
        // Test invalid cases
        #expect(!OCRValidator.isValid(""))
        #expect(!OCRValidator.isValid("   ")) // Whitespace only
        #expect(!OCRValidator.isValid("A")) // Too short
        #expect(!OCRValidator.isValid("12")) // Too short
    }
}
