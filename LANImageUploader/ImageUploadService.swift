//
//  ImageUploadService.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation
import AMSMB2
import UIKit

/// Service responsible for uploading images to an SMB share.
final class ImageUploadService {
    static let shared = ImageUploadService()
    
    private init() {}
    
    /// Errors specific to the upload process.
    enum UploadError: LocalizedError {
        case fileUnreadable
        case dataPreparationFailed
        case passwordMissing
        case invalidServerURL
        case clientInitializationFailed(String)
        case directoryNotFound(String)
        case smbError(String)
        case custom(String)
        
        var errorDescription: String? {
            switch self {
            case .fileUnreadable: return "The image file could not be read."
            case .dataPreparationFailed: return "Unable to prepare the image for upload."
            case .passwordMissing: return "Your server password is missing."
            case .invalidServerURL: return "The server address looks invalid."
            case .clientInitializationFailed(let msg): return "Failed to initialize SMB client: \(msg)"
            case .directoryNotFound(let dir): return "Target directory '\(dir)' does not exist on the server."
            case .smbError(let msg): return msg
            case .custom(let msg): return msg
            }
        }
    }

    /// Uploads a single image to the specified SMB share.
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool = false,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        guard let originalImage = UIImage(contentsOfFile: image.fileURL.path) else {
            throw UploadError.fileUnreadable
        }

        guard let imageData = originalImage.jpegData(compressionQuality: 1.0) else {
            throw UploadError.dataPreparationFailed
        }

        guard let serverURL = URL(string: "smb://\(settings.serverIP)") else {
            throw UploadError.invalidServerURL
        }

        guard let client = SMB2Manager(
            url: serverURL,
            credential: URLCredential(
                user: settings.username,
                password: password,
                persistence: .forSession
            )
        ) else {
            throw UploadError.clientInitializationFailed(settings.serverIP)
        }

        do {
            try await client.connectShare(name: settings.shareName)
            
            let targetDir = settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\")) ?? ""
            let destinationPath = targetDir.isEmpty ? "\(image.name).jpg" : "\(targetDir)/\(image.name).jpg"

            // Check for duplicates if not overwriting
            if !overwrite {
                let parentPath = targetDir.isEmpty ? "" : targetDir
                do {
                    let contents = try await client.contentsOfDirectory(atPath: parentPath)
                    if contents.contains(where: { $0.name == "\(image.name).jpg" }) {
                        try? await client.disconnectShare()
                        throw UploadError.custom("already_exists") // Special marker for UI to handle
                    }
                } catch {
                    // Ignore if parentPath doesn't exist yet, we'll catch it below
                }
            }

            // Ensure target directory exists
            if !targetDir.isEmpty {
                do {
                    _ = try await client.contentsOfDirectory(atPath: targetDir)
                } catch {
                    throw UploadError.directoryNotFound(targetDir)
                }
            }

            // Perform the upload
            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
                let totalSize = Double(imageData.count)
                let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
                onProgress(progressFraction)
                return true
            }

            try? await client.disconnectShare()
        } catch let error as UploadError {
            throw error
        } catch {
            try? await client.disconnectShare()
            throw UploadError.smbError(error.localizedDescription)
        }
    }
}
