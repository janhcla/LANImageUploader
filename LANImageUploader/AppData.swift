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

final class CapturedImageTimestampFormatter: @unchecked Sendable {
    static let shared = CapturedImageTimestampFormatter()

    private let lock = NSLock()
    private let formatter: DateFormatter

    private init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        self.formatter = formatter
    }

    func string(from date: Date, timeZone: TimeZone = .current) -> String {
        lock.withLock {
            formatter.timeZone = timeZone
            return formatter.string(from: date)
        }
    }
}

protocol ServerPasswordPersisting: AnyObject {
    func save(_ password: String) throws
    func password() -> String?
}

final class KeychainServerPasswordStore: ServerPasswordPersisting {
    private let passwordKey: String

    init(passwordKey: String = Constants.Keychain.serverPassword) {
        self.passwordKey = passwordKey
    }

    func save(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw NSError(
                domain: "KeychainError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode password"]
            )
        }

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
            throw NSError(
                domain: "KeychainError",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to save password"]
            )
        }
    }

    func password() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecReturnData as String: NSNumber(value: true),
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

final class InMemoryServerPasswordStore: ServerPasswordPersisting {
    private var storedPassword: String?

    func save(_ password: String) throws {
        storedPassword = password
    }

    func password() -> String? {
        storedPassword
    }
}

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
    let id: UUID
    var name: String
    var fileURL: URL
    var crop: DocumentCrop?
    var isDocumentScan: Bool
    var rotation: ImageRotation

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        crop: DocumentCrop? = nil,
        isDocumentScan: Bool = false,
        rotation: ImageRotation = .degrees0
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.crop = crop
        self.isDocumentScan = isDocumentScan
        self.rotation = rotation
    }

    enum CodingKeys: String, CodingKey {
        case id, name, fileURL, crop, isDocumentScan, rotation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        crop = try container.decodeIfPresent(DocumentCrop.self, forKey: .crop)
        isDocumentScan = try container.decodeIfPresent(Bool.self, forKey: .isDocumentScan) ?? false
        rotation = try container.decodeIfPresent(ImageRotation.self, forKey: .rotation) ?? .degrees0
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
    private struct SendableImage: @unchecked Sendable {
        let value: UIImage
    }

    @Published var images: [CapturedImage] = [] {
        didSet { saveImageQueue() }
    }
    @Published var settings: ServerSettings {
        didSet { saveSettingsToUserDefaults() }
    }
    @Published var ocrText: String = ""
    @Published var imageName: String = ""
    @Published var scanStatus: String = ""
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var selectedImageIDs: Set<UUID> = []
    @Published var pendingUploadFiles: [UploadableFile]? = nil
    @Published private(set) var pendingUploadSourceImageIDs: Set<UUID>? = nil

    // PDF Settings defaults
    @AppStorage(Constants.UserDefaults.defaultGalleryOutputMode) var defaultGalleryOutputMode: GalleryOutputMode = .separateImages
    @AppStorage(Constants.UserDefaults.pdfPageSize) var pdfPageSize: PDFPageSize = .a4
    @AppStorage(Constants.UserDefaults.pdfImageLayout) var pdfImageLayout: PDFImageLayout = .fit
    @AppStorage(Constants.UserDefaults.pdfIncludePageNumbers) var pdfIncludePageNumbers: Bool = true
    @AppStorage(Constants.UserDefaults.pdfJPEGQuality) var pdfJPEGQuality: Double = 0.85
    @AppStorage(Constants.UserDefaults.pdfCompressionLevel) var pdfCompressionLevel: PDFCompressionLevel = .medium
    @AppStorage(Constants.UserDefaults.imageMaxPixelDimension) var imageMaxPixelDimension: Double = 2500
    @AppStorage(Constants.UserDefaults.stripImageMetadata) var stripImageMetadata: Bool = true

    private let passwordStore: ServerPasswordPersisting
    private let settingsKey = Constants.UserDefaults.serverSettings
    private let imageQueueKey = Constants.UserDefaults.capturedImageQueue
    private let persistsImageQueue: Bool

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
        premiumAccess: PremiumAccessController = PremiumAccessController(store: KeychainPremiumAccessStore()),
        passwordStore: ServerPasswordPersisting = KeychainServerPasswordStore(),
        persistsImageQueue: Bool = NSClassFromString("XCTestCase") == nil
    ) {
        self.fileService = fileService
        self.uploadService = uploadService
        self.discoveryService = discoveryService
        self.hapticService = hapticService
        self.premiumAccess = premiumAccess
        self.passwordStore = passwordStore
        self.persistsImageQueue = persistsImageQueue

        self.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: nil, username: "", port: nil)
        if let savedSettings = loadSettingsFromUserDefaults() {
            self.settings = savedSettings
        }
        self.images = loadImageQueue()

        self.premiumAccess.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if persistsImageQueue && images.isEmpty {
            Task { @MainActor [weak self] in
                await self?.restoreLegacyImageQueueIfNeeded()
            }
        }
    }

    func clearNamingData() {
        imageName = ""
        ocrText = ""
    }

    func setPendingUploadFiles(_ files: [UploadableFile]) {
        pendingUploadFiles = files
        pendingUploadSourceImageIDs = files.reduce(into: Set<UUID>()) { ids, file in
            ids.formUnion(file.sourceImageIDs)
        }
    }

    func retainPendingUploadFilesForRetry(_ files: [UploadableFile]) {
        pendingUploadFiles = files
    }

    func clearPendingUploadFiles() {
        pendingUploadFiles = nil
        pendingUploadSourceImageIDs = nil
    }

    @discardableResult
    func saveCapturedImage(
        _ image: UIImage,
        crop: DocumentCrop? = nil,
        isDocumentScan: Bool? = nil,
        capturedAt date: Date = Date(),
        id: UUID = UUID()
    ) async throws -> CapturedImage {
        let sendableImage = SendableImage(value: image)
        let data = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let data = sendableImage.value.jpegData(compressionQuality: 0.8) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return data
            }
        }.value

        return try await saveCapturedImageData(
            data,
            crop: crop,
            isDocumentScan: isDocumentScan,
            capturedAt: date,
            id: id
        )
    }

    @discardableResult
    func saveCapturedImageData(
        _ data: Data,
        crop: DocumentCrop? = nil,
        isDocumentScan: Bool? = nil,
        capturedAt date: Date = Date(),
        id: UUID = UUID()
    ) async throws -> CapturedImage {
        let timestamp = CapturedImageTimestampFormatter.shared.string(from: date)
        let uniqueSuffix = id.uuidString.prefix(8).lowercased()
        let fileName = "IMG_\(timestamp)_\(uniqueSuffix).jpg"

        let fileURL = try await fileService.saveImage(data, fileName: fileName)
        let captured = CapturedImage(
            id: id,
            name: fileName.removingSuffix(".jpg"),
            fileURL: fileURL,
            crop: crop,
            isDocumentScan: isDocumentScan ?? (crop != nil)
        )

        await MainActor.run {
            images.append(captured)
        }

        return captured
    }

    @discardableResult
    func deleteSelectedImages() async -> Bool {
        let idsToDelete = selectedImageIDs
        let imagesToDelete = images.filter { idsToDelete.contains($0.id) }
        var deletedIDs = Set<UUID>()
        var failedDeletions = 0

        for image in imagesToDelete {
            do {
                try await fileService.removeItem(at: image.fileURL)
                deletedIDs.insert(image.id)
            } catch {
                failedDeletions += 1
            }
        }
        let deletedIDsForUI = deletedIDs
        let failedDeletionsForUI = failedDeletions
        await MainActor.run {
            images.removeAll { deletedIDsForUI.contains($0.id) }
            selectedImageIDs.subtract(deletedIDsForUI)
            if failedDeletionsForUI == 0 && !deletedIDsForUI.isEmpty {
                hapticService.playNotification(type: .success)
            }
        }
        return failedDeletions == 0
    }

    @discardableResult
    func deleteAllRetainedImages() async -> Bool {
        let retainedImages = images
        var deletedIDs = Set<UUID>()
        var failedDeletions = 0
        for image in retainedImages {
            do {
                try await fileService.removeItem(at: image.fileURL)
                deletedIDs.insert(image.id)
            } catch {
                failedDeletions += 1
            }
        }
        let deletedIDsForUI = deletedIDs
        await MainActor.run {
            images.removeAll { deletedIDsForUI.contains($0.id) }
            selectedImageIDs.subtract(deletedIDsForUI)
        }
        return failedDeletions == 0
    }

    @discardableResult
    func deleteRetainedImages(withIDs idsToDelete: Set<UUID>) async -> Bool {
        guard !idsToDelete.isEmpty else { return true }
        let imagesToDelete = images.filter { idsToDelete.contains($0.id) }
        var deletedIDs = Set<UUID>()
        var failedDeletions = 0
        for image in imagesToDelete {
            do {
                try await fileService.removeItem(at: image.fileURL)
                deletedIDs.insert(image.id)
            } catch {
                failedDeletions += 1
            }
        }
        let deletedIDsForUI = deletedIDs
        await MainActor.run {
            images.removeAll { deletedIDsForUI.contains($0.id) }
            selectedImageIDs.subtract(deletedIDsForUI)
        }
        return failedDeletions == 0
    }

    func updateCrop(for id: UUID, crop: DocumentCrop) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        images[index].crop = crop.clamped()
        images[index].isDocumentScan = true
    }

    func rotateImage(withID id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        images[index].rotation = images[index].rotation.nextClockwise
    }

    /// Replaces one retained image without changing its position in the queue.
    /// This is used by Retake so the old image cannot remain as a hidden duplicate.
    @MainActor
    func replaceImage(withID id: UUID, with replacement: CapturedImage) {
        guard let index = images.firstIndex(where: { $0.id == id }) else {
            images.append(replacement)
            return
        }
        images[index] = replacement
        selectedImageIDs.remove(id)
    }

    // Save images to a dated folder
    // Save a new captured image, reusable for camera and retake
    func saveCapturedUIImage(
        _ image: UIImage,
        suggestedPrefix: String = "IMG",
        id: UUID = UUID()
    ) async throws -> CapturedImage {
        let timestamp = CapturedImageTimestampFormatter.shared.string(from: Date())
        let uniqueSuffix = id.uuidString.prefix(8).lowercased()
        let fileName = "\(suggestedPrefix)_\(timestamp)_\(uniqueSuffix).jpg"

        let sendableImage = SendableImage(value: image)
        let data = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let data = sendableImage.value.jpegData(compressionQuality: 0.8) else {
                    throw NSError(
                        domain: "ImageError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"]
                    )
                }
                return data
            }
        }.value

        let fileURL = try await fileService.saveImage(data, fileName: fileName)
        let captured = CapturedImage(
            id: id,
            name: fileName.replacingOccurrences(of: ".jpg", with: ""),
            fileURL: fileURL
        )
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
        try passwordStore.save(password)
    }

    func getPassword() -> String? {
        passwordStore.password()
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

    private func saveImageQueue() {
        guard persistsImageQueue else { return }
        guard let data = try? JSONEncoder().encode(images) else { return }
        UserDefaults.standard.set(data, forKey: imageQueueKey)
    }

    private func loadImageQueue() -> [CapturedImage] {
        guard persistsImageQueue else { return [] }
        guard let data = UserDefaults.standard.data(forKey: imageQueueKey),
              let savedImages = try? JSONDecoder().decode([CapturedImage].self, from: data)
        else {
            return []
        }
        return savedImages.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    @MainActor
    private func restoreLegacyImageQueueIfNeeded() async {
        guard images.isEmpty else { return }
        let documentsDirectory = await fileService.documentsDirectory
        let imagesDirectory = documentsDirectory.appendingPathComponent("images")
        guard let urls = try? await fileService.contentsOfDirectory(at: imagesDirectory) else { return }
        let restored = urls
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map {
                CapturedImage(
                    name: $0.deletingPathExtension().lastPathComponent,
                    fileURL: $0
                )
            }
        if !restored.isEmpty {
            images = restored
        }
    }
}

extension AppData {
    @MainActor
    static var preview: AppData {
        AppData(
            fileService: FileService.shared,
            uploadService: ImageUploadService.shared,
            discoveryService: NetworkDiscovery.shared,
            hapticService: HapticFeedbackService.shared
        )
    }
}
