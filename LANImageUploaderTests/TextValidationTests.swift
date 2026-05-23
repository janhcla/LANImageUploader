//
//  TextValidationTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct TextValidationTests {

    @Test func testFullMode() {
        #expect(OCRValidator.sanitizedText(from: "Valid Name", mode: .full) == "Valid Name")
        #expect(OCRValidator.sanitizedText(from: " Image 123 ", mode: .full) == "Image 123")
        #expect(OCRValidator.sanitizedText(from: "", mode: .full) == nil)
        #expect(OCRValidator.sanitizedText(from: "   ", mode: .full) == nil)
        #expect(OCRValidator.sanitizedText(from: "A", mode: .full) == nil)
    }

    @Test func testNumbersMode() {
        #expect(OCRValidator.sanitizedText(from: "123", mode: .numbers) == "123")
        #expect(OCRValidator.sanitizedText(from: "1a2b3", mode: .numbers) == "123")
        #expect(OCRValidator.sanitizedText(from: "Room 12B / 34", mode: .numbers) == "1234")
        #expect(OCRValidator.sanitizedText(from: "  987  ", mode: .numbers) == "987")
        #expect(OCRValidator.sanitizedText(from: "abc", mode: .numbers) == nil)
        #expect(OCRValidator.sanitizedText(from: "No digits", mode: .numbers) == nil)
    }

    @Test func testCPRMode() {
        #expect(OCRValidator.sanitizedText(from: "3112991234", mode: .cpr) == "311299-1234")
        #expect(OCRValidator.sanitizedText(from: "311299-1234", mode: .cpr) == "311299-1234")
        #expect(OCRValidator.sanitizedText(from: "120580–1234", mode: .cpr) == "120580-1234")
        #expect(OCRValidator.sanitizedText(from: "CPR: 3112991234", mode: .cpr) == "311299-1234")
        #expect(OCRValidator.sanitizedText(from: "311299 \u{2014} 1234", mode: .cpr) == "311299-1234")
        #expect(OCRValidator.sanitizedText(from: "321299-1234", mode: .cpr) == nil) // Invalid day
        #expect(OCRValidator.sanitizedText(from: "311399-1234", mode: .cpr) == nil) // Invalid month
        #expect(OCRValidator.sanitizedText(from: "001299-1234", mode: .cpr) == nil) // Invalid day
        #expect(OCRValidator.sanitizedText(from: "310224-1234", mode: .cpr) == nil) // Feb 31st
        #expect(OCRValidator.sanitizedText(from: "290223-1234", mode: .cpr) == nil) // Feb 29th non-leap year
        #expect(OCRValidator.sanitizedText(from: "290224-1234", mode: .cpr) == "290224-1234") // Feb 29th leap year
        #expect(OCRValidator.sanitizedText(from: "123456789", mode: .cpr) == nil) // 9 digits
        #expect(OCRValidator.sanitizedText(from: "12345678901", mode: .cpr) == nil) // 11 digits
        #expect(OCRValidator.sanitizedText(from: "121256-123", mode: .cpr) == nil)
        #expect(OCRValidator.sanitizedText(from: "121256-12345", mode: .cpr) == nil)
        #expect(OCRValidator.sanitizedText(from: "ID: 150688-4321 is valid", mode: .cpr) == "150688-4321")
    }
}
