//
//  AppData.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Foundation
import Security
import SwiftUI

// Add this struct
struct NetworkInfo {
    let serverIP: String
    let shareName: String
    let targetDirectory: String?
}

struct CapturedImage: Identifiable, Codable {
    let id = UUID()
    var name: String
    var fileURL: URL

    enum CodingKeys: String, CodingKey {
        case id, name, fileURL
    }
}

struct ServerSettings: Codable {
    var baseURL: String
}

enum UploadStatus: Equatable {
    case idle
    case uploading(Double)
    case success
    case failure(String)
}

class AppData: ObservableObject {
    @Published var images: [CapturedImage] = []
    @Published var settings: ServerSettings {
        didSet {
            saveSettingsToUserDefaults()
        }
    }
    @Published var ocrText: String = ""
    @Published var imageName: String = ""
    @Published var scanStatus: String = ""

    var isConfigured: Bool {
        !settings.baseURL.isEmpty && getAPIKey() != nil
    }

    private let apiKeyKey = "companionAPIKey"
    private let settingsKey = "serverSettings"
    private let fileManager = FileManager.default
    internal let documentsDirectory: URL  // Changed from `private` to `internal`

    // Add function to clear naming data
    func clearNamingData() {
        imageName = ""
        ocrText = ""
    }

    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.settings = ServerSettings(baseURL: "")
        if let savedSettings = loadSettingsFromUserDefaults() {
            self.settings = savedSettings
        }
    }

    // Save images to a dated folder
    func saveImagesToDatedFolder(for date: Date = Date()) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let datedFolderURL = documentsDirectory.appendingPathComponent(dateString)

        var savedCount = 0
        var alreadySavedCount = 0

        do {
            try fileManager.createDirectory(at: datedFolderURL, withIntermediateDirectories: true)
            for image in images {
                let destinationURL = datedFolderURL.appendingPathComponent(
                    image.fileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: image.fileURL, to: destinationURL)
                    savedCount += 1
                } else {
                    alreadySavedCount += 1
                }
            }

            // Update scan status based on results
            if savedCount > 0 && alreadySavedCount > 0 {
                scanStatus =
                    "\(savedCount) images saved to archive. \(alreadySavedCount) images were already saved."
            } else if savedCount > 0 {
                scanStatus = "\(savedCount) images saved to archive."
            } else if alreadySavedCount > 0 {
                scanStatus = "All images were already saved to archive."
            } else {
                scanStatus = "No images to save."
            }

            print(
                "Images saved to \(datedFolderURL.path): \(savedCount) new, \(alreadySavedCount) already existed"
            )
        } catch {
            scanStatus = "Failed to save images: \(error.localizedDescription)"
            print("Failed to save images: \(error.localizedDescription)")
        }
    }

    // Get list of archived dates
    func getArchivedDates() -> [String] {
        do {
            let folders = try fileManager.contentsOfDirectory(atPath: documentsDirectory.path)
            return folders.filter {
                $0.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            }
            .sorted(by: >)
        } catch {
            print("Failed to get archived dates: \(error)")
            return []
        }
    }

    // Get image URLs for a specific date
    func getImagesForDate(_ dateString: String) -> [URL] {
        let datedFolderURL = documentsDirectory.appendingPathComponent(dateString)
        do {
            let files = try fileManager.contentsOfDirectory(
                at: datedFolderURL, includingPropertiesForKeys: nil)
            return files.filter { ["jpg", "png"].contains($0.pathExtension.lowercased()) }
        } catch {
            print("Failed to get images for \(dateString): \(error)")
            return []
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(
                domain: "KeychainError",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to delete existing API key"])
        }

        if !apiKey.isEmpty {
            let apiKeyData = apiKey.data(using: .utf8)!
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: apiKeyKey,
                kSecValueData as String: apiKeyData
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(
                    domain: "KeychainError",
                    code: Int(addStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save API key"])
            }
        }
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveSettingsToUserDefaults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    private func loadSettingsFromUserDefaults() -> ServerSettings? {
        if let savedData = UserDefaults.standard.data(forKey: settingsKey) {
            let decoder = JSONDecoder()
            return try? decoder.decode(ServerSettings.self, from: savedData)
        }
        return nil
    }
}
