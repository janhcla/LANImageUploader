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
final class ImageUploadService: ImageUploadServiceProtocol {
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
        case authenticationFailed
        case shareNotFound(String)
        case hostUnreachable(String)
        case timeout
        case fileAlreadyExists(String)
        case accessDenied
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
            case .authenticationFailed: return "The server rejected the username or password."
            case .shareNotFound(let share): return "The share '\(share)' could not be reached."
            case .hostUnreachable(let host): return "Cannot reach the server at \(host)."
            case .timeout: return "The connection to the server timed out."
            case .fileAlreadyExists(let file): return "File '\(file)' already exists on the server."
            case .accessDenied: return "Access denied. You don't have permission to write to this share."
            case .smbError(let msg): return msg
            case .custom(let msg): return msg
            }
        }
        
        var guidance: String {
            switch self {
            case .fileUnreadable, .dataPreparationFailed:
                return "Try removing this image from the queue and capturing it again."
            case .passwordMissing, .authenticationFailed:
                return "Open Settings and verify your SMB credentials."
            case .invalidServerURL, .clientInitializationFailed, .hostUnreachable:
                return "Check that both devices are on the same network and that the server IP is correct."
            case .directoryNotFound, .shareNotFound:
                return "Confirm the share and optional target directory exist on the server, then update Settings."
            case .timeout:
                return "Check your Wi-Fi connection and ensure the server is powered on."
            case .fileAlreadyExists:
                return "Choose Rename or Overwrite when prompted before retrying."
            case .accessDenied:
                return "Check the permissions for your user account on the SMB server."
            case .smbError, .custom:
                return "Review the server settings and your network connection, then retry the upload."
            }
        }
        
        var action: UploadFailureDetail.Action? {
            switch self {
            case .passwordMissing, .authenticationFailed, .invalidServerURL, .clientInitializationFailed, .directoryNotFound, .shareNotFound, .accessDenied:
                return .openSettings
            default:
                return nil
            }
        }
    }

    /// Uploads a single image to the specified SMB share.
    func upload(
        image: CapturedImage,
        settings: ServerSettings,
        password: String,
        overwrite: Bool = false,
        onProgress: @escaping @Sendable (Double) -> Void
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
            let sanitizedName = image.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
            let destinationPath = targetDir.isEmpty ? "\(sanitizedName).jpg" : "\(targetDir)/\(sanitizedName).jpg"

            // Check for duplicates if not overwriting
            if !overwrite {
                let parentPath = targetDir.isEmpty ? "" : targetDir
                do {
                    let contents = try await client.contentsOfDirectory(atPath: parentPath)
                    if contents.contains(where: { $0.name == "\(sanitizedName).jpg" }) {
                        try? await client.disconnectShare()
                        throw UploadError.fileAlreadyExists(image.name)
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
                    throw mapUnderlyingError(error, image: image)
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
        } catch {
            try? await client.disconnectShare()
            throw mapUnderlyingError(error, image: image)
        }
    }
    
    private func mapUnderlyingError(_ error: Error, image: CapturedImage) -> UploadError {
        if let uploadError = error as? UploadError {
            return uploadError
        }
        
        let nsError = error as NSError
        
        // Handle AMSMB2 Error Domain
        if nsError.domain == "AMSMB2ErrorDomain" {
            switch nsError.code {
            case 0x00000002, 0xC0000034: // STATUS_NO_SUCH_FILE, STATUS_OBJECT_NAME_NOT_FOUND
                return .directoryNotFound("Specified path not found")
            case 0xC0000022: // STATUS_ACCESS_DENIED
                return .accessDenied
            case 0xC0000035: // STATUS_OBJECT_NAME_COLLISION
                return .fileAlreadyExists(image.name)
            default:
                break
            }
        }
        
        // Handle POSIX Errors
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(EACCES), Int(EPERM):
                return .authenticationFailed
            case Int(ENOENT):
                return .directoryNotFound("Specified path not found")
            case Int(ETIMEDOUT):
                return .timeout
            case Int(EADDRNOTAVAIL), Int(EHOSTUNREACH):
                return .hostUnreachable("Server unreachable")
            default:
                break
            }
        }
        
        // Handle URL Errors (Networking)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return .hostUnreachable("Server not found")
            default:
                break
            }
        }
        
        return .smbError(error.localizedDescription)
    }
}
