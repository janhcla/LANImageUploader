//
//  FileServiceTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct FileServiceTests {

    @Test func testSharedInitialization() {
        // Test that the singleton can be accessed
        let instance1 = FileService.shared
        let instance2 = FileService.shared

        // Verify it is indeed a singleton
        #expect(ObjectIdentifier(instance1) == ObjectIdentifier(instance2))
    }

    @Test func testDocumentsDirectoryExists() async {
        // Test that the documents directory URL can be retrieved and is valid
        let shared = FileService.shared
        let url = await shared.documentsDirectory
        #expect(url.isFileURL)
    }

    @Test("Test archive images date regex with valid and invalid dates", arguments: [
        ("2024-01-01", true),
        ("2024-12-31", true),
        ("invalid-date", false),
        ("2024-1-1", false)
    ])
    func testArchiveImagesDateRegex(dateString: String, isValid: Bool) {
        let isMatch = (try? dateString.wholeMatch(of: /^\d{4}-\d{2}-\d{2}$/)) != nil

        #expect(isMatch == isValid)
    }
}
