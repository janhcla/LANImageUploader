//
//  FileActor.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

/// Actor responsible for low-level file system operations on a background thread.
actor FileActor {
    private let fileManager = FileManager.default
    
    /// The app's Documents directory.
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func createDirectory(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    func copyItem(at src: URL, to dst: URL) throws {
        try fileManager.copyItem(at: src, to: dst)
    }
    
    func removeItem(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    
    func write(data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}
