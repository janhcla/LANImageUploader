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
struct NetworkInfo: Equatable {
    let serverIP: String
    let shareName: String
    let targetDirectory: String?
}

/// Represents the granular state of the SMB connection process.
enum ConnectionStatus: Equatable {
    /// No active connection attempt.
    case disconnected
    /// Actively searching for servers via Bonjour or Subnet scan.
    case discovery(DiscoveryState)
    /// Connecting to a specific IP or Hostname.
    case connecting(String)
    /// Authenticating with the server.
    case authenticating
    /// Successfully connected and validated.
    case connected(NetworkInfo)
    /// Connection failed with a reason.
    case failure(String)
}

/// Represents the specific sub-state of the discovery process.
enum DiscoveryState: Equatable {
    /// Scanning the local subnet for open port 445.
    case subnetScan(progress: Double)
    /// Browsing for _smb._tcp services via Bonjour.
    case bonjourSearch
    /// Resolving a Bonjour service name to an IP address.
    case resolving(String)
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
    var serverIP: String
    var shareName: String
    var targetDirectory: String?
    var username: String
    var port: Int?  // Add this line
}

enum UploadStatus: Equatable {
    case idle
    case uploading(Double)
    case success
    case failure(UploadFailureDetail)
}

struct UploadFailureDetail: Equatable {
    enum Action: Equatable {
        case openSettings
    }

    let reason: String
    let guidance: String
    let action: Action?

    var combinedMessage: String {
        if guidance.isEmpty { return reason }
        return "\(reason)\n\(guidance)"
    }
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

    private let passwordKey = "serverPassword"
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
        self.settings = ServerSettings(
            serverIP: "", shareName: "", targetDirectory: nil, username: "")
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

    func savePassword(_ password: String) throws {
        let passwordData = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "KeychainError", code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to save password"])
        }
    }

    func getPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
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
