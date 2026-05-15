//
//  TextValidationTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct TextValidationTests {

    @Test func fullOCRAcceptsReadableNamesAndRejectsEmptyText() {
        #expect(OCRValidator.sanitizedText(from: "Valid Name", mode: .full) == "Valid Name")
        #expect(OCRValidator.sanitizedText(from: " Image 123 ", mode: .full) == "Image 123")
        #expect(OCRValidator.sanitizedText(from: "", mode: .full) == nil)
        #expect(OCRValidator.sanitizedText(from: "   ", mode: .full) == nil)
        #expect(OCRValidator.sanitizedText(from: "A", mode: .full) == nil)
    }

    @Test func numbersOCRExtractsDigitsOnly() {
        #expect(OCRValidator.sanitizedText(from: "Room 12B / 34", mode: .numbers) == "1234")
        #expect(OCRValidator.sanitizedText(from: "  987  ", mode: .numbers) == "987")
        #expect(OCRValidator.sanitizedText(from: "No digits", mode: .numbers) == nil)
    }

    @Test func cprOCRNormalizesSupportedFormats() {
        #expect(OCRValidator.sanitizedText(from: "120580-1234", mode: .cpr) == "120580-1234")
        #expect(OCRValidator.sanitizedText(from: "120580–1234", mode: .cpr) == "120580-1234")
        #expect(OCRValidator.sanitizedText(from: "1205801234", mode: .cpr) == "120580-1234")
        #expect(OCRValidator.sanitizedText(from: "CPR 120580 1234", mode: .cpr) == nil)
        #expect(OCRValidator.sanitizedText(from: "12345", mode: .cpr) == nil)
    }
}
