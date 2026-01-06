//
//  FileServiceProtocol.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

protocol FileServiceProtocol: Sendable {
    var documentsDirectory: URL { get }
    
    func createDirectory(at url: URL) throws
    func fileExists(at url: URL) -> Bool
    func copyItem(at src: URL, to dst: URL) throws
    func removeItem(at url: URL) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func contentsOfDirectory(atPath path: String) throws -> [String]
    
    func archiveImages(_ images: [CapturedImage], for date: Date) throws -> (saved: Int, existing: Int)
    func getArchivedDates() -> [String]
    func getImagesForDate(_ dateString: String) -> [URL]
    func saveImage(_ data: Data, fileName: String) throws -> URL
}
