//
//  FileServiceProtocol.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation

protocol FileServiceProtocol: Sendable {
    var documentsDirectory: URL { get async }
    
    func createDirectory(at url: URL) async throws
    func fileExists(at url: URL) async -> Bool
    func copyItem(at src: URL, to dst: URL) async throws
    func removeItem(at url: URL) async throws
    func contentsOfDirectory(at url: URL) async throws -> [URL]
    func contentsOfDirectory(atPath path: String) async throws -> [String]
    
    func archiveImages(_ images: [CapturedImage], for date: Date) async throws -> (saved: Int, existing: Int)
    func getArchivedDates() async -> [String]
    func getImagesForDate(_ dateString: String) async -> [URL]
    func saveImage(_ data: Data, fileName: String) async throws -> URL
}