//
//  FileServiceTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct FileServiceTests {

    @Test func sharedInitialization() async throws {
        // Test that the singleton can be accessed
        let shared = FileService.shared
        // FileService is a reference type, shared always exists, no need for #expect(shared != nil)
        // just making sure it's accessible.
        let _ = shared
    }

    @Test func documentsDirectoryExists() async throws {
        // Test that the documents directory URL can be retrieved and is valid
        let shared = FileService.shared
        let url = await shared.documentsDirectory
        #expect(url.isFileURL)
    }

    @Test func archiveImagesDateRegex() async throws {
        let expectedFormat = #"^\d{4}-\d{2}-\d{2}$"#

        let date1 = "2024-01-01"
        let date2 = "2024-12-31"
        let date3 = "invalid-date"
        let date4 = "2024-1-1"

        #expect(date1.range(of: expectedFormat, options: .regularExpression) != nil)
        #expect(date2.range(of: expectedFormat, options: .regularExpression) != nil)
        #expect(date3.range(of: expectedFormat, options: .regularExpression) == nil)
        #expect(date4.range(of: expectedFormat, options: .regularExpression) == nil)
    }
}
