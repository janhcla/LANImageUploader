//
//  FileService.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

/// Service responsible for all local file system operations.
final class FileService {
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
}
