//
//  UploadView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

@MainActor
private final class UploadTaskCoordinator: ObservableObject {
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func start(operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        let currentGeneration = UUID()
        generation = currentGeneration
        task = Task { [weak self] in
            await operation()
            guard let self, self.generation == currentGeneration else { return }
            self.task = nil
        }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
    }
}

@MainActor
struct PendingUploadFileDeletionOutcome {
    let remainingFiles: [UploadableFile]
    let error: Error?
}

@MainActor
enum PendingUploadFileDeletion {
    static func removeSequentially(
        _ files: [UploadableFile],
        remove: (URL) async throws -> Void
    ) async -> PendingUploadFileDeletionOutcome {
        var remainingFiles = files

        for file in files {
            do {
                try await remove(file.fileURL)
                remainingFiles.removeAll { $0.id == file.id }
            } catch {
                return PendingUploadFileDeletionOutcome(remainingFiles: remainingFiles, error: error)
            }
        }

        return PendingUploadFileDeletionOutcome(remainingFiles: [], error: nil)
    }
}

struct UploadView: View {
    let fallbackToGalleryImages: Bool
    let automaticallyStarts: Bool
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var uploadStatuses: [UUID: UploadStatus] = [:]
    @State private var navigateToSettings = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var uploadTasks: [UUID: Bool] = [:]
    @StateObject private var uploadCoordinator = UploadTaskCoordinator()
    var uploadFiles: [UploadableFile] {
        if let pending = appData.pendingUploadFiles {
            return pending
        }
        guard fallbackToGalleryImages else { return [] }
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
    @State private var showLocalDeletionConfirmation = false
    @State private var isFinishing = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateFile: UploadableFile?
    @State private var navigateToFullUnlock = false

    init(fallbackToGalleryImages: Bool = true, automaticallyStarts: Bool = false) {
        self.fallbackToGalleryImages = fallbackToGalleryImages
        self.automaticallyStarts = automaticallyStarts
    }

    var areSettingsComplete: Bool {
        ServerConnectionReadiness.isComplete(
            settings: appData.settings,
            password: appData.getPassword()
        )
    }

    var hasFailedUploads: Bool {
        uploadStatuses.values.contains { if case .failure = $0 { return true }; return false }
    }

    var hasActiveUploads: Bool {
        uploadStatuses.values.contains { if case .uploading = $0 { return true }; return false }
    }

    var body: some View {
        BackgroundContainerView {
                ZStack {
                    if uploadFiles.isEmpty {
                        ContentUnavailableView {
                            Label("Nothing to Upload", systemImage: "tray")
                        } description: {
                            Text("Capture an image or prepare files from Gallery, then return here to review the queue.")
                        } actions: {
                            NavigationLink("Open Gallery") {
                                GalleryView()
                                    .environmentObject(appData)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        List(uploadFiles) { file in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(file.name)
                                    .font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                statusView(for: file)
                            }
                            .padding(.vertical, 5)
                        }
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                    if showSuccessBanner {
                        SuccessBanner(message: isPendingPDFUpload ? "PDF uploaded successfully!" : "All images have been uploaded successfully!")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: showSuccessBanner)
                            .task {
                                try? await Task.sleep(for: .seconds(3))
                                guard !Task.isCancelled else { return }
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    showSuccessBanner = false
                                }
                            }
                    }
                }
                .navigationTitle(isPendingPDFUpload ? "Upload PDF" : "Upload Images")
                .safeAreaInset(edge: .top) {
                    trialStatusView
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if hasActiveUploads {
                            Button("Abort Upload", role: .destructive) { abortUploads() }
                        } else if !uploadFiles.isEmpty && !areAllUploadsSuccessful && !isFinishing {
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
                        if hasFailedUploads && !isFinishing {
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
                    Button("Keep Both") {
                        if let file = duplicateFile { renameFile(file) }
                    }
                    Button("Overwrite", role: .destructive) {
                        if let file = duplicateFile { runSingleUpload(file, overwrite: true) }
                    }
                    Button("Cancel", role: .cancel) { duplicateFile = nil }
                } message: {
                    Text("A file named '\(duplicateFile?.name ?? "")' already exists. Keep both creates a timestamped copy; overwrite replaces the server copy.")
                }
                .navigationDestination(isPresented: $navigateToSettings) {
                    SettingsView().environmentObject(appData)
                }
                .navigationDestination(isPresented: $navigateToFullUnlock) {
                    FullAppUnlockView().environmentObject(appData)
                }
                .safeAreaInset(edge: .bottom) {
                    if areAllUploadsSuccessful {
                        VStack(spacing: 10) {
                            Button {
                                Task { await finishUploadKeepingOriginals() }
                            } label: {
                                if isFinishing {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Done")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isFinishing)

                            Button("Remove Local Originals…", role: .destructive) {
                                showLocalDeletionConfirmation = true
                            }
                            .disabled(isFinishing)
                        }
                        .padding()
                        .background(.bar)
                    } else {
                        EmptyView()
                    }
                }
                .confirmationDialog(
                    "Remove Local Originals?",
                    isPresented: $showLocalDeletionConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove \(localOriginalCount) Local \(localOriginalCount == 1 ? "File" : "Files")", role: .destructive) {
                        Task { await clearAndDeleteAllImages() }
                    }
                    Button("Keep Local Originals", role: .cancel) {}
                } message: {
                    Text("The server upload has completed. This permanently removes the matching local originals from Gallery; the server copies are not affected.")
                }
                .onChange(of: uploadStatuses) { _, _ in checkUploadStatus() }
                .onAppear {
                    uploadStatuses = Dictionary(uniqueKeysWithValues: uploadFiles.map { ($0.id, .idle) })
                    guard !uploadFiles.isEmpty else { return }
                    if automaticallyStarts && !autoUploadTriggered && areSettingsComplete {
                        startUpload()
                        autoUploadTriggered = true
                    } else if automaticallyStarts && !areSettingsComplete && !autoUploadTriggered {
                        showSettingsPrompt = true
                        autoUploadTriggered = true
                    }
                }
                .onDisappear {
                    if hasActiveUploads {
                        abortUploads()
                    }
                }
        }
    }

    private var localOriginalCount: Int {
        let sourceIDs = appData.pendingUploadSourceImageIDs ?? Set(uploadFiles.map(\.id))
        return sourceIDs.isEmpty ? appData.images.count : sourceIDs.count
    }

    @ViewBuilder
    private var trialStatusView: some View {
        if !uploadFiles.isEmpty && appData.premiumAccess.state.shouldShowTrialStatus {
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
            ProgressView(value: progress) {
                Text("Uploading")
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityValue("\(Int(progress * 100)) percent")
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure(let detail):
            VStack(alignment: .leading, spacing: 6) {
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
                    .multilineTextAlignment(.leading)
                if !detail.guidance.isEmpty {
                    Text(detail.guidance)
                        .font(.caption2)
                        .foregroundStyle(Color.red.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                if detail.action == .openSettings {
                    Button("Update Settings") {
                        navigateToSettings = true
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func startUpload() {
        guard !areAllUploadsSuccessful, !isFinishing else { return }
        guard appData.premiumAccess.state.canUpload else {
            navigateToFullUnlock = true
            return
        }

        runUploadBatch(uploadFiles)
    }

    func retryFailedUploads() {
        let failedFiles = uploadFiles.filter {
            if case .failure = uploadStatuses[$0.id] { return true }
            return false
        }

        runUploadBatch(failedFiles)
    }

    func abortUploads() {
        uploadCoordinator.cancel()
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

    func finishUploadKeepingOriginals() async {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }

        if let pending = appData.pendingUploadFiles {
            let deletion = await PendingUploadFileDeletion.removeSequentially(pending) { fileURL in
                try await appData.fileService.removeItem(at: fileURL)
            }
            if deletion.error != nil {
                appData.retainPendingUploadFilesForRetry(deletion.remainingFiles)
                showError = true
                errorMessage = "The upload succeeded, but a temporary local upload file could not be removed. Your originals were kept. Try again."
                return
            }
        }

        appData.clearPendingUploadFiles()
        uploadStatuses.removeAll()
        uploadTasks.removeAll()
        areAllUploadsSuccessful = false
        appData.clearNamingData()
        dismiss()
    }

    func clearAndDeleteAllImages() async {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        uploadCoordinator.cancel()
        let sourceImageIDs = appData.pendingUploadSourceImageIDs ?? (appData.pendingUploadFiles?
            .reduce(into: Set<UUID>()) { ids, file in
                ids.formUnion(file.sourceImageIDs)
            } ?? [])

        if let pending = appData.pendingUploadFiles {
            let deletion = await PendingUploadFileDeletion.removeSequentially(pending) { fileURL in
                try await appData.fileService.removeItem(at: fileURL)
            }
            if deletion.error != nil {
                await MainActor.run {
                    appData.retainPendingUploadFilesForRetry(deletion.remainingFiles)
                    let remainingIDs = Set(deletion.remainingFiles.map(\.id))
                    uploadStatuses = uploadStatuses.filter { remainingIDs.contains($0.key) }
                    uploadTasks = uploadTasks.filter { remainingIDs.contains($0.key) }
                    showError = true
                    errorMessage = "The upload succeeded, but a local upload file could not be removed. Your originals were kept. Try clearing the queue again."
                }
                return
            }
        }
        let sourceCleanupSucceeded: Bool
        if sourceImageIDs.isEmpty {
            sourceCleanupSucceeded = await appData.deleteAllRetainedImages()
        } else {
            sourceCleanupSucceeded = await appData.deleteRetainedImages(withIDs: sourceImageIDs)
        }
        await MainActor.run {
            appData.clearPendingUploadFiles()
            uploadStatuses.removeAll()
            uploadTasks.removeAll()
            areAllUploadsSuccessful = false
            appData.clearNamingData()
            if sourceCleanupSucceeded {
                dismiss()
            } else {
                showError = true
                errorMessage = "The upload succeeded, but one or more original local files could not be removed. They remain in Gallery."
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
                    guard uploadTasks[file.id] == true else { return }
                    uploadStatuses[file.id] = .uploading(progress)
                }
            }
            try Task.checkCancellation()

            await MainActor.run {
                appData.premiumAccess.recordSuccessfulUpload()
                uploadStatuses[file.id] = .success
                uploadTasks.removeValue(forKey: file.id)
            }
        } catch is CancellationError {
            await MainActor.run {
                uploadTasks.removeValue(forKey: file.id)
                uploadStatuses[file.id] = .failure(
                    UploadFailureDetail(
                        reason: "Upload aborted.",
                        guidance: "Start the upload again when you're ready to continue.",
                        action: nil
                    )
                )
                showSuccessBanner = false
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
                runSingleUpload(updatedFile)
            }
        } else {
            if let index = appData.images.firstIndex(where: { $0.id == file.id }) {
                appData.images[index].name = newName
            }
            if let updatedImage = appData.images.first(where: { $0.name == newName }) {
                let updatedFile = UploadableFile(id: updatedImage.id, name: updatedImage.name, fileURL: updatedImage.fileURL, kind: .jpeg)
                runSingleUpload(updatedFile)
            }
        }
    }

    private func runSingleUpload(_ file: UploadableFile, overwrite: Bool = false) {
        uploadCoordinator.start { [self] in
            await uploadFile(file, overwrite: overwrite)
        }
    }

    private func runUploadBatch(_ files: [UploadableFile]) {
        guard !files.isEmpty else { return }
        uploadCoordinator.start { [self] in
            // Keep the batch bounded to one in-flight file. ImageUploadService
            // prepares each JPEG/PDF as Data, so unbounded parallel uploads can
            // retain dozens of large buffers for a multi-page scan.
            for file in files {
                guard !Task.isCancelled else { return }
                guard self.appData.premiumAccess.state.canUpload else {
                    self.navigateToFullUnlock = true
                    return
                }
                await self.uploadFile(file)
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
