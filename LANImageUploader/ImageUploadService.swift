//
//  ImageUploadService.swift
//  LANImageUploader
//
//  Created by AI on 06/01/2026.
//

import Foundation
import AMSMB2

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

    /// Uploads a single file to the specified SMB share.
    func upload(
        file: UploadableFile,
        settings: ServerSettings,
        password: String,
        overwrite: Bool = false,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try Task.checkCancellation()
        let fileData: Data

        switch file.kind {
        case .jpeg, .pdf:
            do {
                fileData = try Data(contentsOf: file.fileURL)
            } catch {
                throw UploadError.fileUnreadable
            }
        }

        guard let serverURL = URL(string: "smb://\(settings.serverIP)") else {
            throw UploadError.invalidServerURL
        }

        try Task.checkCancellation()

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
            try Task.checkCancellation()
            
            let targetDir = settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\")) ?? ""

            let destinationName = destinationFileName(for: file)
            let destinationPath = targetDir.isEmpty ? destinationName : "\(targetDir)/\(destinationName)"

            // Check for duplicates if not overwriting
            if !overwrite {
                try Task.checkCancellation()
                let parentPath = targetDir.isEmpty ? "" : targetDir
                do {
                    let contents = try await client.contentsOfDirectory(atPath: parentPath)
                    if contents.contains(where: { $0.name == destinationName }) {
                        throw UploadError.fileAlreadyExists(destinationName)
                    }
                } catch let error as UploadError {
                    throw error
                } catch {
                    // Ignore if parentPath doesn't exist yet, we'll catch it below
                }
            }

            // Ensure target directory exists
            if !targetDir.isEmpty {
                try Task.checkCancellation()
                do {
                    _ = try await client.contentsOfDirectory(atPath: targetDir)
                } catch {
                    throw mapUnderlyingError(error, fileName: destinationName)
                }
            }

            // Perform the upload. Some SMB servers can surface a late fsync/write error
            // after the complete file has been committed, so verify the remote size before
            // reporting failure.
            do {
                try await client.write(data: fileData, toPath: destinationPath) { progressBytes in
                    guard !Task.isCancelled else { return false }
                    let totalSize = Double(fileData.count)
                    let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
                    onProgress(progressFraction)
                    return !Task.isCancelled
                }
                try Task.checkCancellation()
            } catch {
                if Task.isCancelled {
                    throw CancellationError()
                }
                let writeError = error
                if (try? await remoteFileMatchesExpectedContents(
                    client: client,
                    path: destinationPath,
                    expectedData: fileData
                )) == true {
                    onProgress(1.0)
                } else {
                    throw writeError
                }
            }

            try? await client.disconnectShare()
        } catch is CancellationError {
            try? await client.disconnectShare()
            throw CancellationError()
        } catch {
            try? await client.disconnectShare()
            throw mapUnderlyingError(error, fileName: destinationFileName(for: file))
        }
    }

    private func destinationFileName(for file: UploadableFile) -> String {
        var sanitizedName = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedName = sanitizedName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        if sanitizedName.isEmpty {
            sanitizedName = file.kind.displayName
        }

        let lowerName = sanitizedName.lowercased()
        if lowerName.hasSuffix("." + file.kind.fileExtension) {
            sanitizedName = String(sanitizedName.dropLast(file.kind.fileExtension.count + 1))
        }

        return "\(sanitizedName).\(file.kind.fileExtension)"
    }

    private func remoteFileMatchesExpectedContents(
        client: SMB2Manager,
        path: String,
        expectedData: Data
    ) async throws -> Bool {
        let attributes = try await client.attributesOfItem(atPath: path)
        guard let size = attributes[URLResourceKey.fileSizeKey] as? NSNumber else {
            return false
        }
        guard size.intValue == expectedData.count else {
            return false
        }
        let remoteData = try await client.contents(
            atPath: path,
            range: UInt64(0)..<UInt64(expectedData.count)
        )
        return remoteData == expectedData
    }
    
    private func mapUnderlyingError(_ error: Error, fileName: String) -> UploadError {
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
                return .fileAlreadyExists(fileName)
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
