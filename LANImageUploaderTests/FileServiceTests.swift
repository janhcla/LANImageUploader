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

struct FileActorTests {

    let fileManager = FileManager.default
    let temporaryDirectory = FileManager.default.temporaryDirectory

    @Test func testDocumentsDirectory() async {
        let actor = FileActor()
        let documentsDirectory = await actor.documentsDirectory
        #expect(documentsDirectory.isFileURL)
        #expect(documentsDirectory.path.contains("Documents"))
    }

    @Test func testCreateDirectory() async throws {
        let actor = FileActor()
        let testDirURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        // Ensure directory doesn't exist initially
        #expect(!fileManager.fileExists(atPath: testDirURL.path))

        try await actor.createDirectory(at: testDirURL)

        // Verify it was created
        #expect(fileManager.fileExists(atPath: testDirURL.path))
        var isDir: ObjCBool = false
        #expect(fileManager.fileExists(atPath: testDirURL.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        // Clean up
        try fileManager.removeItem(at: testDirURL)
    }

    @Test func testFileExists() async throws {
        let actor = FileActor()
        let testFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        #expect(await !actor.fileExists(at: testFileURL))

        // Create file
        try Data("test".utf8).write(to: testFileURL)

        #expect(await actor.fileExists(at: testFileURL))

        // Clean up
        try fileManager.removeItem(at: testFileURL)
    }

    @Test func testCopyItem() async throws {
        let actor = FileActor()
        let sourceURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try Data("test copy".utf8).write(to: sourceURL)

        try await actor.copyItem(at: sourceURL, to: destURL)

        #expect(fileManager.fileExists(atPath: destURL.path))
        let copiedData = try Data(contentsOf: destURL)
        #expect(String(data: copiedData, encoding: .utf8) == "test copy")

        // Clean up
        try fileManager.removeItem(at: sourceURL)
        try fileManager.removeItem(at: destURL)
    }

    @Test func testRemoveItem() async throws {
        let actor = FileActor()
        let testFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        try Data("test remove".utf8).write(to: testFileURL)
        #expect(fileManager.fileExists(atPath: testFileURL.path))

        try await actor.removeItem(at: testFileURL)
        #expect(!fileManager.fileExists(atPath: testFileURL.path))
    }

    @Test func testContentsOfDirectoryURL() async throws {
        let actor = FileActor()
        let testDirURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: testDirURL, withIntermediateDirectories: true)

        let file1URL = testDirURL.appendingPathComponent("file1.txt")
        let file2URL = testDirURL.appendingPathComponent("file2.txt")
        try Data("1".utf8).write(to: file1URL)
        try Data("2".utf8).write(to: file2URL)

        let contents = try await actor.contentsOfDirectory(at: testDirURL)
        #expect(contents.count == 2)
        let paths = contents.map { $0.lastPathComponent }
        #expect(paths.contains("file1.txt"))
        #expect(paths.contains("file2.txt"))

        // Clean up
        try fileManager.removeItem(at: testDirURL)
    }

    @Test func testContentsOfDirectoryPath() async throws {
        let actor = FileActor()
        let testDirURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: testDirURL, withIntermediateDirectories: true)

        let file1URL = testDirURL.appendingPathComponent("file1.txt")
        try Data("1".utf8).write(to: file1URL)

        let contents = try await actor.contentsOfDirectory(atPath: testDirURL.path)
        #expect(contents.count == 1)
        #expect(contents.contains("file1.txt"))

        // Clean up
        try fileManager.removeItem(at: testDirURL)
    }

    @Test func testWriteData() async throws {
        let actor = FileActor()
        let testFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = Data("test write".utf8)

        try await actor.write(data: data, to: testFileURL)

        #expect(fileManager.fileExists(atPath: testFileURL.path))
        let writtenData = try Data(contentsOf: testFileURL)
        #expect(String(data: writtenData, encoding: .utf8) == "test write")

        // Clean up
        try fileManager.removeItem(at: testFileURL)
    }
}
