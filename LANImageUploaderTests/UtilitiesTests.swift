//
//  UtilitiesTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct UtilitiesTests {

    @Test func testRemovingSuffix() {
        // Happy path: Suffix exists
        #expect("filename.jpg".removingSuffix(".jpg") == "filename")
        #expect("document.pdf".removingSuffix(".pdf") == "document")
        #expect("image.jpeg".removingSuffix(".jpg") == "image.jpeg") // Doesn't match exact suffix

        // Edge cases
        // 1. Suffix doesn't exist
        #expect("filename".removingSuffix(".jpg") == "filename")

        // 2. Empty string
        #expect("".removingSuffix(".jpg") == "")

        // 3. Empty suffix
        #expect("filename".removingSuffix("") == "filename")

        // 4. String equals suffix
        #expect(".jpg".removingSuffix(".jpg") == "")

        // 5. Suffix is longer than the string
        #expect("a".removingSuffix("abc") == "a")

        // 6. Suffix with special characters
        #expect("hello world!!!".removingSuffix("!!!") == "hello world")

        // 7. Case sensitivity (should be case sensitive)
        #expect("filename.JPG".removingSuffix(".jpg") == "filename.JPG")
    }
}
