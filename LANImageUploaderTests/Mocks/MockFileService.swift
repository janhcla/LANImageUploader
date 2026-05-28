//
//  MockFileService.swift
//  LANImageUploaderTests
//
//  Created by AI on 06/01/2026.
//

import Foundation
@testable import LANImageUploader

final class MockFileService: FileServiceProtocol, @unchecked Sendable {
    var mockDocumentsDirectory = URL(fileURLWithPath: "/tmp/mock")
    var documentsDirectory: URL {
        get async { mockDocumentsDirectory }
    }
    
    var createDirectoryCalled = false
    var createdDirectories: [URL] = []
    func createDirectory(at url: URL) async throws {
        createDirectoryCalled = true
        createdDirectories.append(url)
    }
    
    var fileExistsResult = true
    func fileExists(at url: URL) async -> Bool {
        fileExistsResult
    }
    
    var copyItemCalled = false
    var copiedItems: [(src: URL, dst: URL)] = []
    func copyItem(at src: URL, to dst: URL) async throws {
        copyItemCalled = true
        copiedItems.append((src, dst))
    }
    
    var removeItemCalled = false
    var removedItems: [URL] = []
    func removeItem(at url: URL) async throws {
        removeItemCalled = true
        removedItems.append(url)
    }
    
    var contentsOfDirectoryResult: [URL] = []
    func contentsOfDirectory(at url: URL) async throws -> [URL] {
        contentsOfDirectoryResult
    }
    
    var contentsOfDirectoryPathResult: [String] = []
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        contentsOfDirectoryPathResult
    }
    
    var archiveImagesResult: (saved: Int, existing: Int) = (0, 0)
    var archiveImagesError: Error?
    func archiveImages(_ images: [CapturedImage], for date: Date) async throws -> (saved: Int, existing: Int) {
        if let error = archiveImagesError { throw error }
        return archiveImagesResult
    }
    
    var getArchivedDatesResult: [String] = []
    func getArchivedDates() async -> [String] {
        getArchivedDatesResult
    }
    
    var getImagesForDateResult: [URL] = []
    func getImagesForDate(_ dateString: String) async -> [URL] {
        getImagesForDateResult
    }
    
    var saveImageResult: URL = URL(fileURLWithPath: "/tmp/mock/images/test.jpg")
    var saveImageError: Error?
    var savedImages: [(data: Data, fileName: String)] = []
    func saveImage(_ data: Data, fileName: String) async throws -> URL {
        if let error = saveImageError { throw error }
        savedImages.append((data, fileName))
        return saveImageResult
    }

    var restoreImagesResult: RestorationResult = RestorationResult(successCount: 0, failureCount: 0, restoredImages: [])
    func restoreImages(operations: [RestoreOperation]) async -> RestorationResult {
        return restoreImagesResult
    }
}
