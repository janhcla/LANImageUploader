//
//  FileService.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

/// Service responsible for all local file system operations, delegating to a background actor.
final class FileService: FileServiceProtocol {
    static let shared = FileService()
    private let actor = FileActor()
    
    private init() {}
    
    /// The app's Documents directory.
    var documentsDirectory: URL {
        get async { await actor.documentsDirectory }
    }
    
    /// Creates a directory at the specified URL if it doesn't exist.
    func createDirectory(at url: URL) async throws {
        try await actor.createDirectory(at: url)
    }
    
    /// Checks if a file exists at the specified URL.
    func fileExists(at url: URL) async -> Bool {
        await actor.fileExists(at: url)
    }
    
    /// Copies a file from source to destination.
    func copyItem(at src: URL, to dst: URL) async throws {
        try await actor.copyItem(at: src, to: dst)
    }
    
    /// Removes a file or directory at the specified URL.
    func removeItem(at url: URL) async throws {
        try await actor.removeItem(at: url)
    }
    
    /// Lists contents of a directory as URLs.
    func contentsOfDirectory(at url: URL) async throws -> [URL] {
        try await actor.contentsOfDirectory(at: url)
    }
    
    /// Lists contents of a directory as Strings.
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        try await actor.contentsOfDirectory(atPath: path)
    }

    /// Saves a list of images to a dated folder in the Documents directory.
    func archiveImages(_ images: [CapturedImage], for date: Date = Date()) async throws -> (saved: Int, existing: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let docs = await actor.documentsDirectory
        let datedFolderURL = docs.appendingPathComponent(dateString)

        var savedCount = 0
        var alreadySavedCount = 0

        try await actor.createDirectory(at: datedFolderURL)
        for image in images {
            let destinationURL = datedFolderURL.appendingPathComponent(image.fileURL.lastPathComponent)
            if await !actor.fileExists(at: destinationURL) {
                try await actor.copyItem(at: image.fileURL, to: destinationURL)
                savedCount += 1
            } else {
                alreadySavedCount += 1
            }
        }
        
        return (savedCount, alreadySavedCount)
    }

    /// Gets a list of archived date strings (YYYY-MM-DD).
    func getArchivedDates() async -> [String] {
        do {
            let docs = await actor.documentsDirectory
            let folders = try await actor.contentsOfDirectory(atPath: docs.path)
            return folders.filter {
                $0.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            }
            .sorted(by: >)
        } catch {
            return []
        }
    }

    /// Gets image URLs for a specific archived date.
    func getImagesForDate(_ dateString: String) async -> [URL] {
        let docs = await actor.documentsDirectory
        let datedFolderURL = docs.appendingPathComponent(dateString)
        do {
            let files = try await actor.contentsOfDirectory(at: datedFolderURL)
            return files.filter { ["jpg", "png"].contains($0.pathExtension.lowercased()) }
        } catch {
            return []
        }
    }

    /// Saves image data to the 'images' folder and returns its URL.
    func saveImage(_ data: Data, fileName: String) async throws -> URL {
        let docs = await actor.documentsDirectory
        let imagesFolderURL = docs.appendingPathComponent("images")
        try await actor.createDirectory(at: imagesFolderURL)
        let fileURL = imagesFolderURL.appendingPathComponent(fileName)
        try await actor.write(data: data, to: fileURL)
        return fileURL
    }
}