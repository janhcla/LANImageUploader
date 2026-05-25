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
    var uploadFiles: [UploadableFile] {
        if let pending = appData.pendingUploadFiles {
            return pending
        }
        return appData.images.map {
            UploadableFile(id: $0.id, name: $0.name, fileURL: $0.fileURL, kind: .jpeg)
        }
    }
    var isPendingPDFUpload: Bool {
        guard let pending = appData.pendingUploadFiles else { return false }
        return pending.contains { $0.kind == .pdf }
    }
    @State private var autoUploadTriggered = false
    @State private var showSettingsPrompt = false
    @State private var showSuccessBanner = false
    @State private var areAllUploadsSuccessful = false
    @State private var showClearSuccess = false
    @State private var navigateToHome = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateFile: UploadableFile?
    @State private var overwriteConfirmed = false
    @State private var navigateToFullUnlock = false

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
                    List(uploadFiles) { file in
                        HStack {
                            Text(file.name)
                                .lineLimit(1)
                            Spacer()
                            statusView(for: file)
                        }
                        .padding(.vertical, 4)
                    }
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .navigationTitle(isPendingPDFUpload ? "Upload PDF" : "Upload Images")
                    .safeAreaInset(edge: .top) {
                        trialStatusView
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            if hasActiveUploads {
                                Button("Abort Upload", role: .destructive) { abortUploads() }
                            } else if !uploadFiles.isEmpty {
                                Button("Start Upload") {
                                    if !appData.premiumAccess.state.canUpload {
                                        navigateToFullUnlock = true
                                    } else if areSettingsComplete {
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
                            if let file = duplicateFile { renameFile(file) }
                        }
                        Button("Overwrite", role: .destructive) {
                            overwriteConfirmed = true
                            if let file = duplicateFile { Task { await uploadFile(file, overwrite: true) } }
                        }
                        Button("Cancel", role: .cancel) { duplicateFile = nil }
                    } message: {
                        Text("A file named '\(duplicateFile?.name ?? "")' already exists. Do you want to rename it or overwrite the existing file?")
                    }
                    if uploadFiles.isEmpty {
                        VStack {
                            Spacer()
                            Text("Nothing to upload - capture images first")
                                .foregroundStyle(.gray)
                                .padding()
                            Spacer()
                        }
                    }
                    if showSuccessBanner {
                        SuccessBanner(message: isPendingPDFUpload ? "PDF uploaded successfully!" : "All images have been uploaded successfully!")
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
                .navigationDestination(isPresented: $navigateToFullUnlock) {
                    FullAppUnlockView().environmentObject(appData)
                }
                .safeAreaInset(edge: .bottom) {
                    if areAllUploadsSuccessful {
                        Button(appData.pendingUploadFiles != nil ? "Clear upload queue" : "Clear queue & delete all images", role: .destructive) {
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
                    uploadStatuses = Dictionary(uniqueKeysWithValues: uploadFiles.map { ($0.id, .idle) })
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
    private var trialStatusView: some View {
        if appData.premiumAccess.state.shouldShowTrialStatus {
            HStack {
                Text("\(appData.premiumAccess.state.remainingTrialUploads) trial uploads remaining")
                    .font(.caption)
                    .foregroundStyle(appData.premiumAccess.state.canUpload ? Color.secondary : Color.red)
                Spacer()
                Button("Full App Unlock") {
                    navigateToFullUnlock = true
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
    }

    @ViewBuilder
    func statusView(for file: UploadableFile) -> some View {
        switch uploadStatuses[file.id] ?? .idle {
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
        guard appData.premiumAccess.state.canUpload else {
            navigateToFullUnlock = true
            return
        }

        if appData.premiumAccess.state.isFullAppUnlocked {
            for file in uploadFiles {
                Task { await uploadFile(file) }
            }
            return
        }

        Task {
            for file in uploadFiles {
                guard appData.premiumAccess.state.canUpload else {
                    await MainActor.run { navigateToFullUnlock = true }
                    return
                }
                await uploadFile(file)
            }
        }
    }

    func retryFailedUploads() {
        let failedFiles = uploadFiles.filter {
            if case .failure = uploadStatuses[$0.id] { return true }
            return false
        }

        if appData.premiumAccess.state.isFullAppUnlocked {
            for file in failedFiles {
                Task { await uploadFile(file) }
            }
            return
        }

        Task {
            for file in failedFiles {
                guard appData.premiumAccess.state.canUpload else {
                    await MainActor.run { navigateToFullUnlock = true }
                    return
                }
                await uploadFile(file)
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
        let totalImages = uploadFiles.count
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
        if appData.pendingUploadFiles != nil {
            // Prepared uploads are temporary derivatives; original scans remain in Gallery.
            if let pending = appData.pendingUploadFiles {
                for file in pending {
                    try? await appData.fileService.removeItem(at: file.fileURL)
                }
            }
            await MainActor.run {
                appData.pendingUploadFiles = nil
                uploadStatuses.removeAll()
                uploadTasks.removeAll()
                areAllUploadsSuccessful = false
                appData.clearNamingData()
                showClearSuccess = true
            }
        } else {
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
    }

    func uploadFile(_ file: UploadableFile, overwrite: Bool = false) async {
        guard appData.premiumAccess.state.canUpload else {
            await presentFailure(
                UploadFailureDetail(
                    reason: "Trial upload limit reached.",
                    guidance: "Unlock the full app to continue uploading files to your server.",
                    action: nil
                ),
                for: file
            )
            await MainActor.run {
                navigateToFullUnlock = true
            }
            return
        }

        guard let password = appData.getPassword() else {
            await presentFailure(
                UploadFailureDetail(
                    reason: "Your server password is missing.",
                    guidance: "Open Settings and enter the correct SMB password, then try the upload again.",
                    action: .openSettings
                ),
                for: file
            )
            return
        }

        await MainActor.run {
            uploadStatuses[file.id] = .uploading(0)
            uploadTasks[file.id] = true
        }

        do {
            try await appData.uploadService.upload(
                file: file,
                settings: appData.settings,
                password: password,
                overwrite: overwrite
            ) { progress in
                DispatchQueue.main.async {
                    uploadStatuses[file.id] = .uploading(progress)
                }
            }

            await MainActor.run {
                appData.premiumAccess.recordSuccessfulUpload()
                uploadStatuses[file.id] = .success
                uploadTasks.removeValue(forKey: file.id)
            }
        } catch {
            if let uploadError = error as? ImageUploadService.UploadError {
                if case .fileAlreadyExists = uploadError {
                    await MainActor.run {
                        duplicateFile = file
                        showDuplicatePrompt = true
                        uploadTasks.removeValue(forKey: file.id)
                        uploadStatuses[file.id] = .idle
                    }
                    return
                }
            }
            
            let detail = detailForUploadError(error, file: file)
            await presentFailure(detail, for: file, clearTask: true)
        }
    }

    private func detailForUploadError(_ error: Error, file: UploadableFile) -> UploadFailureDetail {
        if let uploadError = error as? ImageUploadService.UploadError {
            return UploadFailureDetail(
                reason: uploadError.errorDescription ?? "Unknown upload error",
                guidance: uploadError.guidance,
                action: uploadError.action
            )
        }
        
        return UploadFailureDetail(
            reason: "Upload failed: \(error.localizedDescription)",
            guidance: "Review the server settings and your network connection, then retry the upload.",
            action: .openSettings
        )
    }

    private func presentFailure(
        _ detail: UploadFailureDetail,
        for file: UploadableFile,
        clearTask: Bool = false
    ) async {
        await MainActor.run {
            if clearTask {
                uploadTasks.removeValue(forKey: file.id)
            }
            uploadStatuses[file.id] = .failure(detail)
            errorMessage = detail.combinedMessage
            showError = true
            showSuccessBanner = false
        }
    }

    func renameFile(_ file: UploadableFile) {
        let newName = "\(file.name)_\(Int(Date().timeIntervalSince1970))"

        if appData.pendingUploadFiles != nil {
            if let index = appData.pendingUploadFiles?.firstIndex(where: { $0.id == file.id }) {
                appData.pendingUploadFiles?[index].name = newName
            }
            if let updatedFile = appData.pendingUploadFiles?.first(where: { $0.name == newName }) {
                Task { await uploadFile(updatedFile) }
            }
        } else {
            if let index = appData.images.firstIndex(where: { $0.id == file.id }) {
                appData.images[index].name = newName
            }
            if let updatedImage = appData.images.first(where: { $0.name == newName }) {
                let updatedFile = UploadableFile(id: updatedImage.id, name: updatedImage.name, fileURL: updatedImage.fileURL, kind: .jpeg)
                Task { await uploadFile(updatedFile) }
            }
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
