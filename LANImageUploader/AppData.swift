//
//  AppData.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import Foundation
import Combine
import Security
import SwiftUI

struct NetworkInfo: Equatable {
    let serverIP: String
    let shareName: String
    let targetDirectory: String?
}

struct DiscoveredHost: Identifiable, Equatable {
    let id: String
    let name: String?

    var displayName: String {
        if let name = name {
            return "\(name) (\(id))"
        }
        return id
    }
}

enum ConnectionStatus: Equatable {
    case disconnected
    case discovery(DiscoveryState)
    case connecting(String)
    case authenticating
    case connected(NetworkInfo)
    case failure(ConnectionError)
}

enum DiscoveryState: Equatable {
    case subnetScan(progress: Double)
    case bonjourSearch
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
    var port: Int?
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
        didSet { saveSettingsToUserDefaults() }
    }
    @Published var ocrText: String = ""
    @Published var imageName: String = ""
    @Published var scanStatus: String = ""
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var selectedImageIDs: Set<UUID> = []
    @Published var pendingUploadFiles: [UploadableFile]? = nil

    // PDF Settings defaults
    @AppStorage(Constants.UserDefaults.defaultGalleryOutputMode) var defaultGalleryOutputMode: GalleryOutputMode = .separateImages
    @AppStorage(Constants.UserDefaults.pdfPageSize) var pdfPageSize: PDFPageSize = .a4
    @AppStorage(Constants.UserDefaults.pdfImageLayout) var pdfImageLayout: PDFImageLayout = .fit
    @AppStorage(Constants.UserDefaults.pdfIncludePageNumbers) var pdfIncludePageNumbers: Bool = true
    @AppStorage(Constants.UserDefaults.pdfJPEGQuality) var pdfJPEGQuality: Double = 0.85
    @AppStorage(Constants.UserDefaults.imageMaxPixelDimension) var imageMaxPixelDimension: Double = 2500
    @AppStorage(Constants.UserDefaults.stripImageMetadata) var stripImageMetadata: Bool = true

    private let passwordKey = Constants.Keychain.serverPassword
    private let settingsKey = Constants.UserDefaults.serverSettings

    internal let fileService: FileServiceProtocol
    internal let uploadService: ImageUploadServiceProtocol
    internal let discoveryService: NetworkDiscoveryProtocol
    internal let hapticService: HapticFeedbackServiceProtocol
    let premiumAccess: PremiumAccessController
    private var cancellables: Set<AnyCancellable> = []

    init(
        fileService: FileServiceProtocol,
        uploadService: ImageUploadServiceProtocol,
        discoveryService: NetworkDiscoveryProtocol,
        hapticService: HapticFeedbackServiceProtocol,
        premiumAccess: PremiumAccessController = PremiumAccessController(store: KeychainPremiumAccessStore())
    ) {
        self.fileService = fileService
        self.uploadService = uploadService
        self.discoveryService = discoveryService
        self.hapticService = hapticService
        self.premiumAccess = premiumAccess

        self.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: nil, username: "", port: nil)
        if let savedSettings = loadSettingsFromUserDefaults() {
            self.settings = savedSettings
        }

        self.premiumAccess.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func clearNamingData() {
        imageName = ""
        ocrText = ""
    }

    @discardableResult
    func saveCapturedImage(_ image: UIImage, capturedAt date: Date = Date()) async throws -> CapturedImage {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: date)
        let fileName = "IMG_\(timestamp).jpg"

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let fileURL = try await fileService.saveImage(data, fileName: fileName)
        let captured = CapturedImage(name: fileName.removingSuffix(".jpg"), fileURL: fileURL)

        await MainActor.run {
            images.append(captured)
        }

        return captured
    }

    func deleteSelectedImages() async {
        let idsToDelete = selectedImageIDs
        let imagesToDelete = images.filter { idsToDelete.contains($0.id) }

        for image in imagesToDelete {
            try? await fileService.removeItem(at: image.fileURL)
        }
        await MainActor.run {
            images.removeAll { idsToDelete.contains($0.id) }
            selectedImageIDs.removeAll()
            hapticService.playNotification(type: .success)
        }
    }

    // Save images to a dated folder
    // Save a new captured image, reusable for camera and retake
    func saveCapturedUIImage(_ image: UIImage, suggestedPrefix: String = "IMG") async throws -> CapturedImage {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "\(suggestedPrefix)_\(timestamp).jpg"

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"])
        }

        let fileURL = try await fileService.saveImage(data, fileName: fileName)
        let captured = CapturedImage(name: fileName.replacingOccurrences(of: ".jpg", with: ""), fileURL: fileURL)
        return captured
    }

    func saveImagesToDatedFolder(_ imagesToSave: [CapturedImage]? = nil, for date: Date = Date()) async {
        let targetImages = imagesToSave ?? images
        do {
            let (savedCount, alreadySavedCount) = try await fileService.archiveImages(targetImages, for: date)
            await MainActor.run {
                if savedCount > 0 && alreadySavedCount > 0 {
                    scanStatus = "\(savedCount) images saved to archive. \(alreadySavedCount) images were already saved."
                } else if savedCount > 0 {
                    scanStatus = "\(savedCount) images saved to archive."
                } else if alreadySavedCount > 0 {
                    scanStatus = "All images were already saved to archive."
                } else {
                    scanStatus = "No images to save."
                }
            }
        } catch {
            await MainActor.run {
                scanStatus = "Failed to save images: \(error.localizedDescription)"
            }
        }
    }

    func getArchivedDates() async -> [String] {
        await fileService.getArchivedDates()
    }

    func getImagesForDate(_ dateString: String) async -> [URL] {
        await fileService.getImagesForDate(dateString)
    }

    func savePassword(_ password: String) throws {
        let passwordData = password.data(using: .utf8)!

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save password"])
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

extension AppData {
    static var preview: AppData {
        AppData(
            fileService: FileService.shared,
            uploadService: ImageUploadService.shared,
            discoveryService: NetworkDiscovery.shared,
            hapticService: HapticFeedbackService.shared
        )
    }
}
