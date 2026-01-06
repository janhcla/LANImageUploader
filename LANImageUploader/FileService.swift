//
//  FileService.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

/// Service responsible for all local file system operations.
final class FileService: FileServiceProtocol {
    static let shared = FileService()
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// The app's Documents directory.
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Creates a directory at the specified URL if it doesn't exist.
    func createDirectory(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    /// Checks if a file exists at the specified URL.
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    /// Copies a file from source to destination.
    func copyItem(at src: URL, to dst: URL) throws {
        try fileManager.copyItem(at: src, to: dst)
    }
    
    /// Removes a file or directory at the specified URL.
    func removeItem(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Lists contents of a directory as URLs.
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    /// Lists contents of a directory as Strings.
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }

    /// Saves a list of images to a dated folder in the Documents directory.
    func archiveImages(_ images: [CapturedImage], for date: Date = Date()) throws -> (saved: Int, existing: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let datedFolderURL = documentsDirectory.appendingPathComponent(dateString)

        var savedCount = 0
        var alreadySavedCount = 0

        try createDirectory(at: datedFolderURL)
        for image in images {
            let destinationURL = datedFolderURL.appendingPathComponent(image.fileURL.lastPathComponent)
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.copyItem(at: image.fileURL, to: destinationURL)
                savedCount += 1
            } else {
                alreadySavedCount += 1
            }
        }
        
        return (savedCount, alreadySavedCount)
    }

    /// Gets a list of archived date strings (YYYY-MM-DD).
    func getArchivedDates() -> [String] {
        do {
            let folders = try fileManager.contentsOfDirectory(atPath: documentsDirectory.path)
            return folders.filter {
                $0.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            }
            .sorted(by: >)
        } catch {
            return []
        }
    }

    /// Gets image URLs for a specific archived date.
    func getImagesForDate(_ dateString: String) -> [URL] {
        let datedFolderURL = documentsDirectory.appendingPathComponent(dateString)
        do {
            let files = try fileManager.contentsOfDirectory(at: datedFolderURL, includingPropertiesForKeys: nil)
            return files.filter { ["jpg", "png"].contains($0.pathExtension.lowercased()) }
        } catch {
            return []
        }
    }

    /// Saves image data to the 'images' folder and returns its URL.
    func saveImage(_ data: Data, fileName: String) throws -> URL {
        let imagesFolderURL = documentsDirectory.appendingPathComponent("images")
        try createDirectory(at: imagesFolderURL)
        let fileURL = imagesFolderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}
