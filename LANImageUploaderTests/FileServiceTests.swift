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

    @Test func testGetArchivedDates() async throws {
        let fileService = FileService.shared
        let docsDir = await fileService.documentsDirectory

        let validDates = ["2023-05-15", "2024-01-01", "2024-12-31"]
        let invalidDates = ["2024-1-1", "invalid", "2024-12-31-extra"]

        // Clean up before test just in case
        for date in validDates + invalidDates {
            try? await fileService.removeItem(at: docsDir.appendingPathComponent(date))
        }

        // Create test directories
        for date in validDates + invalidDates {
            let url = docsDir.appendingPathComponent(date)
            try await fileService.createDirectory(at: url)
        }

        let retrievedDates = await fileService.getArchivedDates()

        // Cleanup after test
        for date in validDates + invalidDates {
            try? await fileService.removeItem(at: docsDir.appendingPathComponent(date))
        }

        // Verify
        for validDate in validDates {
            #expect(retrievedDates.contains(validDate))
        }

        for invalidDate in invalidDates {
            #expect(!retrievedDates.contains(invalidDate))
        }

        // Check sorting (descending)
        let filteredRetrieved = retrievedDates.filter { validDates.contains($0) }
        #expect(filteredRetrieved == validDates.sorted(by: >))
    }
}
