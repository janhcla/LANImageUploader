//
//  AppData.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Foundation
import Security
import SwiftUI

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "A keychain operation failed. OSStatus code: \(status)"
        case .dataEncodingFailed:
            return "Failed to encode API key data."
        }
    }
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

@MainActor
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

    private static let apiKeyKey = "companionAPIKey"
    private static let settingsKey = "serverSettings"
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

    nonisolated func saveAPIKey(_ apiKey: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: AppData.apiKeyKey
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(deleteStatus)
        }

        if !apiKey.isEmpty {
            guard let apiKeyData = apiKey.data(using: .utf8) else { throw KeychainError.dataEncodingFailed }

            var addQuery = query
            addQuery[kSecValueData as String] = apiKeyData

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        }
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: AppData.apiKeyKey,
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
            UserDefaults.standard.set(encoded, forKey: AppData.settingsKey)
        }
    }

    private func loadSettingsFromUserDefaults() -> ServerSettings? {
        if let savedData = UserDefaults.standard.data(forKey: AppData.settingsKey) {
            let decoder = JSONDecoder()
            return try? decoder.decode(ServerSettings.self, from: savedData)
        }
        return nil
    }
}
