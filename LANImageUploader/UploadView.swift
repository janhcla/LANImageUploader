//
//  UploadView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct UploadView: View {
    @EnvironmentObject var appData: AppData
    @State private var uploadStatuses: [UUID: UploadStatus] = [:]
    @State private var navigateToSettings = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var uploadTasks: [UUID: Bool] = [:]
    @State private var autoUploadTriggered = false
    @State private var showSettingsPrompt = false
    @State private var showSuccessBanner = false
    @State private var areAllUploadsSuccessful = false
    @State private var showClearSuccess = false
    @State private var navigateToHome = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateImage: CapturedImage?
    @State private var overwriteConfirmed = false

    var areSettingsComplete: Bool {
        !appData.settings.serverIP.isEmpty && !appData.settings.shareName.isEmpty &&
        !appData.settings.username.isEmpty && appData.getPassword() != nil
    }

    var hasFailedUploads: Bool {
        uploadStatuses.values.contains { if case .failure = $0 { return true }; return false }
    }

    var hasActiveUploads: Bool {
        uploadStatuses.values.contains { if case .uploading = $0 { return true }; return false }
    }

    var body: some View {
        BackgroundContainerView {
            NavigationStack {
                ZStack {
                    List(appData.images) { image in
                        HStack {
                            Text(image.name)
                                .lineLimit(1)
                            Spacer()
                            statusView(for: image)
                        }
                        .padding(.vertical, 4)
                    }
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .navigationTitle("Upload Images")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            if hasActiveUploads {
                                Button("Abort Upload", role: .destructive) { abortUploads() }
                            } else if !appData.images.isEmpty {
                                Button("Start Upload") {
                                    if areSettingsComplete {
                                        startUpload()
                                    } else {
                                        showSettingsPrompt = true
                                    }
                                }
                            }
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            if hasFailedUploads {
                                Button("Retry Failed") { retryFailedUploads() }
                            }
                        }
                    }
                    .alert("Upload Error", isPresented: $showError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(errorMessage)
                    }
                    .alert("Server Settings Required", isPresented: $showSettingsPrompt) {
                        Button("Cancel", role: .cancel) {}
                        Button("Go to Settings") {
                            navigateToSettings = true
                        }
                    } message: {
                        Text("Server settings are incomplete. Uploads cannot proceed without them.")
                    }
                    .alert("Duplicate File", isPresented: $showDuplicatePrompt) {
                        Button("Rename") {
                            renameImage(duplicateImage!)
                        }
                        Button("Overwrite", role: .destructive) {
                            overwriteConfirmed = true
                            Task { await uploadImage(duplicateImage!, overwrite: true) }
                        }
                        Button("Cancel", role: .cancel) { duplicateImage = nil }
                    } message: {
                        Text("A file named '\(duplicateImage?.name ?? "")' already exists. Do you want to rename it or overwrite the existing file?")
                    }
                    if appData.images.isEmpty {
                        VStack {
                            Spacer()
                            Text("Nothing to upload - capture images first")
                                .foregroundStyle(.gray)
                                .padding()
                            Spacer()
                        }
                    }
                    if showSuccessBanner {
                        SuccessBanner(message: "All images have been uploaded successfully!")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.5), value: showSuccessBanner)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showSuccessBanner = false }
                                }
                            }
                    }
                    if showClearSuccess {
                        SuccessBanner(message: "Queue cleared and images deleted successfully!")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.5), value: showClearSuccess)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation {
                                        showClearSuccess = false
                                        navigateToHome = true
                                    }
                                }
                            }
                    }
                }
                .navigationDestination(isPresented: $navigateToHome) {
                    HomeView().environmentObject(appData)
                }
                // ADD: Navigation link
                .navigationDestination(isPresented: $navigateToSettings) {
                    SettingsView().environmentObject(appData)
                }
                .safeAreaInset(edge: .bottom) {
                    if areAllUploadsSuccessful {
                        Button("Clear queue & delete all images", role: .destructive) {
                            Task {
                                await clearAndDeleteAllImages()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    } else {
                        EmptyView()
                    }
                }
                .onChange(of: uploadStatuses) { _, _ in checkUploadStatus() }
                .onAppear {
                    uploadStatuses = Dictionary(
                        uniqueKeysWithValues: appData.images.map { ($0.id, .idle) })
                    if !autoUploadTriggered && areSettingsComplete {
                        startUpload()
                        autoUploadTriggered = true
                    } else if !areSettingsComplete && !autoUploadTriggered {
                        showSettingsPrompt = true
                        autoUploadTriggered = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    func statusView(for image: CapturedImage) -> some View {
        switch uploadStatuses[image.id] ?? .idle {
        case .idle:
            Text("Ready").font(.caption).foregroundStyle(.gray)
        case .uploading(let progress):
            ProgressView(value: progress).progressViewStyle(.linear).frame(width: 100)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure(let detail):
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Failed")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.red)
                }
                Text(detail.reason)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                if !detail.guidance.isEmpty {
                    Text(detail.guidance)
                        .font(.caption2)
                        .foregroundStyle(Color.red.opacity(0.85))
                        .multilineTextAlignment(.trailing)
                }
                if detail.action == .openSettings {
                    Button("Update Settings") {
                        navigateToSettings = true
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    func startUpload() {
        for image in appData.images {
            Task { await uploadImage(image) }
        }
    }

    func retryFailedUploads() {
        for image in appData.images {
            if case .failure = uploadStatuses[image.id] {
                Task { await uploadImage(image) }
            }
        }
    }

    func abortUploads() {
        for (imageID, _) in uploadTasks {
            uploadStatuses[imageID] = .failure(
                UploadFailureDetail(
                    reason: "Upload aborted.",
                    guidance: "Start the upload again when you're ready to continue.",
                    action: nil
                )
            )
        }
        uploadTasks.removeAll()
    }

    func checkUploadStatus() {
        let totalImages = appData.images.count
        let successfulUploads = uploadStatuses.values.filter {
            if case .success = $0 { return true }
            return false
        }.count
        areAllUploadsSuccessful =
            totalImages > 0 && successfulUploads == totalImages && !hasActiveUploads &&
            !hasFailedUploads
        if areAllUploadsSuccessful {
            showSuccessBanner = true
        }
    }

    func clearAndDeleteAllImages() async {
        for image in appData.images {
            try? await appData.fileService.removeItem(at: image.fileURL)
        }
        await MainActor.run {
            appData.images.removeAll()
            uploadStatuses.removeAll()
            uploadTasks.removeAll()
            areAllUploadsSuccessful = false
            appData.clearNamingData()
            showClearSuccess = true
        }
    }

    func uploadImage(_ image: CapturedImage, overwrite: Bool = false) async {
        guard let password = appData.getPassword() else {
            await presentFailure(
                UploadFailureDetail(
                    reason: "Your server password is missing.",
                    guidance: "Open Settings and enter the correct SMB password, then try the upload again.",
                    action: .openSettings
                ),
                for: image
            )
            return
        }

        await MainActor.run {
            uploadStatuses[image.id] = .uploading(0)
            uploadTasks[image.id] = true
        }

        do {
            try await appData.uploadService.upload(
                image: image,
                settings: appData.settings,
                password: password,
                overwrite: overwrite
            ) { progress in
                DispatchQueue.main.async {
                    uploadStatuses[image.id] = .uploading(progress)
                }
            }

            await MainActor.run {
                uploadStatuses[image.id] = .success
                uploadTasks.removeValue(forKey: image.id)
            }
        } catch {
            if let uploadError = error as? ImageUploadService.UploadError {
                if case .custom(let code) = uploadError, code == "already_exists" {
                    await MainActor.run {
                        duplicateImage = image
                        showDuplicatePrompt = true
                        uploadTasks.removeValue(forKey: image.id)
                        uploadStatuses[image.id] = .idle
                    }
                    return
                }
            }
            
            let detail = detailForUploadError(error, image: image)
            await presentFailure(detail, for: image, clearTask: true)
        }
    }

    private func detailForUploadError(_ error: Error, image: CapturedImage) -> UploadFailureDetail {
        if let uploadError = error as? ImageUploadService.UploadError {
            switch uploadError {
            case .fileUnreadable:
                return UploadFailureDetail(
                    reason: "The image file could not be read.",
                    guidance: "Remove this item from the queue and capture it again before retrying.",
                    action: nil
                )
            case .dataPreparationFailed:
                return UploadFailureDetail(
                    reason: "Unable to prepare the image for upload.",
                    guidance: "Try removing the image from the queue and capturing it again.",
                    action: nil
                )
            case .passwordMissing:
                return UploadFailureDetail(
                    reason: "Your server password is missing.",
                    guidance: "Open Settings and enter the correct SMB password, then try the upload again.",
                    action: .openSettings
                )
            case .invalidServerURL:
                return UploadFailureDetail(
                    reason: "The server address looks invalid.",
                    guidance: "Double-check the IP address in Settings and correct it if needed.",
                    action: .openSettings
                )
            case .clientInitializationFailed(let host):
                return UploadFailureDetail(
                    reason: "Failed to initialise the SMB client for \(host).",
                    guidance: "Review the server settings and your network connection, then retry the upload.",
                    action: .openSettings
                )
            case .directoryNotFound(let dir):
                return UploadFailureDetail(
                    reason: "Target directory '\(dir)' does not exist on the server.",
                    guidance: "Update the target directory in Settings so it matches an existing folder on the server.",
                    action: .openSettings
                )
            case .smbError(let msg), .custom(let msg):
                // Fall back to existing string parsing for SMB errors
                return detailForGenericError(msg, image: image)
            }
        }
        
        return detailForGenericError(error.localizedDescription, image: image)
    }

    private func detailForGenericError(_ description: String, image: CapturedImage) -> UploadFailureDetail {
        let lowerDescription = description.lowercased()

        if lowerDescription.contains("logon failure") || lowerDescription.contains("access denied") {
            return UploadFailureDetail(
                reason: "The server rejected the username or password.",
                guidance: "Open Settings and verify the credentials before trying again.",
                action: .openSettings
            )
        }

        if lowerDescription.contains("bad network name") || lowerDescription.contains("tree connect failed") {
            return UploadFailureDetail(
                reason: "The share '\(appData.settings.shareName)' could not be reached.",
                guidance: "Make sure the share name is correct in Settings and that it is accessible from this network.",
                action: .openSettings
            )
        }

        if lowerDescription.contains("no such file") || lowerDescription.contains("not found") || lowerDescription.contains("does not exist") {
            return UploadFailureDetail(
                reason: description,
                guidance: "Confirm the share and optional target directory exist on the server, then update Settings if needed.",
                action: .openSettings
            )
        }

        if lowerDescription.contains("timed out") || lowerDescription.contains("timeout") ||
            lowerDescription.contains("could not connect") || lowerDescription.contains("host is down") ||
            lowerDescription.contains("network is unreachable") {
            return UploadFailureDetail(
                reason: "Cannot reach the server at \(appData.settings.serverIP).",
                guidance: "Check that both devices are on the same network and that the server is powered on.",
                action: nil
            )
        }

        return UploadFailureDetail(
            reason: "Upload failed: \(description)",
            guidance: "Review the server settings and your network connection, then retry the upload.",
            action: .openSettings
        )
    }

    private func presentFailure(
        _ detail: UploadFailureDetail,
        for image: CapturedImage,
        clearTask: Bool = false
    ) async {
        await MainActor.run {
            if clearTask {
                uploadTasks.removeValue(forKey: image.id)
            }
            uploadStatuses[image.id] = .failure(detail)
            errorMessage = detail.combinedMessage
            showError = true
            showSuccessBanner = false
        }
    }

    func renameImage(_ image: CapturedImage) {
        let newName = "\(image.name)_\(Int(Date().timeIntervalSince1970))"
        if let index = appData.images.firstIndex(where: { $0.id == image.id }) {
            // Update existing CapturedImage without passing id
            appData.images[index] = CapturedImage(name: newName, fileURL: image.fileURL)
        }
        if let updatedImage = appData.images.first(where: { $0.name == newName }) {
            Task { await uploadImage(updatedImage) }
        }
    }
}

struct SuccessBanner: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
        }
        .padding(.top, 10)
    }
}

#Preview {
    UploadView()
        .environmentObject(AppData.preview)
}
