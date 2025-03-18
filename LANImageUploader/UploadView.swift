//
//  UploadView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import AMSMB2
import SwiftUI

struct UploadView: View {
    @EnvironmentObject var appData: AppData
    @State private var uploadStatuses: [UUID: UploadStatus] = [:]
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
                        Button("Go to Settings", role: .cancel) {}
                        Button("Cancel") {}
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
                .safeAreaInset(edge: .bottom) {
                    if areAllUploadsSuccessful {
                        Button("Clear queue & delete all images", role: .destructive) {
                            clearAndDeleteAllImages()
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
        case .failure(let message):
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).contextMenu {
                Text(message)
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
            uploadStatuses[imageID] = .failure("Upload aborted")
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

    func clearAndDeleteAllImages() {
        for image in appData.images {
            try? FileManager.default.removeItem(at: image.fileURL)
        }
        appData.images.removeAll()
        uploadStatuses.removeAll()
        uploadTasks.removeAll()
        areAllUploadsSuccessful = false
        showClearSuccess = true
    }

    func uploadImage(_ image: CapturedImage, overwrite: Bool = false) async {
        guard let originalImage = UIImage(contentsOfFile: image.fileURL.path),
              let imageData = originalImage.jpegData(compressionQuality: 1.0),
              let password = appData.getPassword() else {
            await MainActor.run {
                uploadStatuses[image.id] = .failure("Invalid image or server settings")
                showError = true
                errorMessage = "Check your server settings and try again."
            }
            return
        }

        await MainActor.run {
            uploadStatuses[image.id] = .uploading(0)
            uploadTasks[image.id] = true
        }

        do {
            let client = SMB2Manager(
                url: URL(string: "smb://\(appData.settings.serverIP)")!,
                credential: URLCredential(
                    user: appData.settings.username,
                    password: password,
                    persistence: .forSession
                )
            )!
            try await client.connectShare(name: appData.settings.shareName)

            let targetDir = appData.settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\")) ?? ""
            let destinationPath = targetDir.isEmpty ? "\(image.name).jpg" : "\(targetDir)/\(image.name).jpg"

            // Check if file exists
            if !overwrite {
                let parentPath = targetDir.isEmpty ? "" : targetDir
                do {
                    let contents = try await client.contentsOfDirectory(atPath: parentPath)
                    if contents.contains(where: { $0.name == "\(image.name).jpg" }) {
                        await MainActor.run {
                            duplicateImage = image
                            showDuplicatePrompt = true
                        }
                        return
                    }
                } catch {
                    // If parentPath doesn't exist, we'll catch it below
                }
            }

            // Verify directory exists if specified
            if !targetDir.isEmpty {
                do {
                    _ = try await client.contentsOfDirectory(atPath: targetDir)
                } catch {
                    throw NSError(domain: "SMBError", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Target directory '\(targetDir)' does not exist on the server."])
                }
            }

            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
                let totalSize = Double(imageData.count)
                let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
                DispatchQueue.main.async {
                    uploadStatuses[image.id] = .uploading(progressFraction)
                }
                return true
            }

            await MainActor.run {
                uploadStatuses[image.id] = .success
                uploadTasks.removeValue(forKey: image.id)
            }

            try await client.disconnectShare()
        } catch {
            await MainActor.run {
                let message: String
                if error.localizedDescription.contains("already exists") {
                    message = "File '\(image.name).jpg' already exists on the server."
                } else if error.localizedDescription.contains("does not exist") {
                    message = error.localizedDescription
                } else {
                    message = "Upload failed: \(error.localizedDescription)"
                }
                uploadStatuses[image.id] = .failure(message)
                showError = true
                errorMessage = message
                uploadTasks.removeValue(forKey: image.id)
            }
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
        .environmentObject(AppData())
}


////
////  UploadView.swift
////  LANImageUploader
////
////  Created by Jan Hagen Clausen on 21/02/2025.
////
//
//import AMSMB2
//import SwiftUI
//
//struct UploadView: View {
//    @EnvironmentObject var appData: AppData
//    @State private var uploadStatuses: [UUID: UploadStatus] = [:]
//    @State private var showError = false
//    @State private var errorMessage = ""
//    @State private var uploadTasks: [UUID: Bool] = [:]
//    @State private var autoUploadTriggered = false
//    @State private var showSettingsPrompt = false
//    @State private var showSuccessBanner = false
//    @State private var areAllUploadsSuccessful = false
//    @State private var showClearSuccess = false
//    @State private var navigateToHome = false
//    @State private var showDuplicatePrompt = false
//    @State private var duplicateImage: CapturedImage?
//    @State private var overwriteConfirmed = false
//
//    var areSettingsComplete: Bool {
//        !appData.settings.serverIP.isEmpty && !appData.settings.shareName.isEmpty &&
//        !appData.settings.username.isEmpty && appData.getPassword() != nil
//    }
//
//    var body: some View {
//        BackgroundContainerView {
//            NavigationStack {
//                ZStack {
//                    List(appData.images) { image in
//                        HStack {
//                            Text(image.name)
//                                .lineLimit(1)
//                            Spacer()
//                            statusView(for: image)
//                        }
//                        .padding(.vertical, 4)
//                    }
//                    
//                    .alert("Duplicate File", isPresented: $showDuplicatePrompt) {
//                        Button("Rename") {
//                            renameImage(duplicateImage!)
//                        }
//                        Button("Overwrite", role: .destructive) {
//                            overwriteConfirmed = true
//                            Task { await uploadImage(duplicateImage!, overwrite: true) }
//                        }
//                        Button("Cancel", role: .cancel) { duplicateImage = nil }
//                    } message: {
//                        Text("A file named '\(duplicateImage?.name ?? "")' already exists. Do you want to rename it or overwrite the existing file?")
//                    }
//                }
//                // ... rest unchanged ...
//        }
//    }
//
//    @ViewBuilder
//    func statusView(for image: CapturedImage) -> some View {
//        switch uploadStatuses[image.id] ?? .idle {
//        case .idle: Text("Ready").font(.caption).foregroundStyle(.gray)
//        case .uploading(let progress): ProgressView(value: progress).frame(width: 100)
//        case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
//        case .failure(let message): Image(systemName: "xmark.circle.fill").foregroundStyle(.red).contextMenu { Text(message) }
//        }
//    }
//
//    func uploadImage(_ image: CapturedImage, overwrite: Bool = false) async {
//        guard let originalImage = UIImage(contentsOfFile: image.fileURL.path),
//              let imageData = originalImage.jpegData(compressionQuality: 1.0),
//              let password = appData.getPassword() else {
//            await MainActor.run {
//                uploadStatuses[image.id] = .failure("Invalid image or settings")
//                showError = true
//                errorMessage = "Check your server settings and try again."
//            }
//            return
//        }
//
//        await MainActor.run {
//            uploadStatuses[image.id] = .uploading(0)
//            uploadTasks[image.id] = true
//        }
//
//        do {
//            let client = SMB2Manager(
//                url: URL(string: "smb://\(appData.settings.serverIP)")!,
//                credential: URLCredential(user: appData.settings.username, password: password, persistence: .forSession)
//            )!
//            try await client.connectShare(name: appData.settings.shareName)
//
//            let targetDir = appData.settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\")) ?? ""
//            let destinationPath = targetDir.isEmpty ? "\(image.name).jpg" : "\(targetDir)/\(image.name).jpg"
//
//            // Check if file exists
//            if !overwrite && (try? await client.attributes(path: destinationPath)) != nil {
//                await MainActor.run {
//                    duplicateImage = image
//                    showDuplicatePrompt = true
//                }
//                return
//            }
//
//            // Verify directory exists
//            if !targetDir.isEmpty {
//                do {
//                    _ = try await client.attributes(path: targetDir)
//                } catch {
//                    throw NSError(domain: "SMBError", code: -4,
//                        userInfo: [NSLocalizedDescriptionKey: "Target directory '\(targetDir)' does not exist on the server."])
//                }
//            }
//
//            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
//                let progressFraction = Double(progressBytes) / Double(imageData.count)
//                DispatchQueue.main.async {
//                    uploadStatuses[image.id] = .uploading(progressFraction)
//                }
//                return true
//            }
//
//            await MainActor.run {
//                uploadStatuses[image.id] = .success
//                uploadTasks.removeValue(forKey: image.id)
//            }
//            try await client.disconnectShare()
//        } catch {
//            await MainActor.run {
//                let message: String
//                if error.localizedDescription.contains("already exists") {
//                    message = "File '\(image.name).jpg' already exists on the server."
//                } else if error.localizedDescription.contains("does not exist") {
//                    message = error.localizedDescription
//                } else {
//                    message = "Upload failed: \(error.localizedDescription)"
//                }
//                uploadStatuses[image.id] = .failure(message)
//                showError = true
//                errorMessage = message
//                uploadTasks.removeValue(forKey: image.id)
//            }
//        }
//    }
//
//    func renameImage(_ image: CapturedImage) {
//        let newName = "\(image.name)_\(Int(Date().timeIntervalSince1970))"
//        if let index = appData.images.firstIndex(where: { $0.id == image.id }) {
//            appData.images[index] = CapturedImage(id: image.id, name: newName, fileURL: image.fileURL)
//        }
//        Task { await uploadImage(appData.images.first(where: { $0.id == image.id })!) }
//    }
//
//    // ... rest unchanged ...
//}
//                    .background(Color.clear)
//                    .scrollContentBackground(.hidden)
//                    .navigationTitle("Upload Images")
//                    .toolbar {
//                        ToolbarItem(placement: .primaryAction) {
//                            if hasActiveUploads {
//                                Button("Abort Upload", role: .destructive) { abortUploads() }
//                            } else if !appData.images.isEmpty {
//                                Button("Start Upload") {
//                                    if areSettingsComplete {
//                                        startUpload()
//                                    } else {
//                                        showSettingsPrompt = true
//                                    }
//                                }
//                            }
//                        }
//                        ToolbarItem(placement: .secondaryAction) {
//                            if hasFailedUploads {
//                                Button("Retry Failed") { retryFailedUploads() }
//                            }
//                        }
//                    }
//                    .alert("Upload Error", isPresented: $showError) {
//                        Button("OK", role: .cancel) {}
//                    } message: {
//                        Text(errorMessage)
//                    }
//                    .alert("Server Settings Required", isPresented: $showSettingsPrompt) {
//                        Button("Go to Settings", role: .cancel) {}
//                        Button("Cancel") {}
//                    } message: {
//                        Text("Server settings are incomplete. Uploads cannot proceed without them.")
//                    }
//                    if appData.images.isEmpty {
//                        VStack {
//                            Spacer()
//                            Text("Nothing to upload - capture images first")
//                                .foregroundStyle(.gray)
//                                .padding()
//                            Spacer()
//                        }
//                    }
//                    if showSuccessBanner {
//                        SuccessBanner(message: "All images have been uploaded successfully!")
//                            .transition(.move(edge: .top).combined(with: .opacity))
//                            .animation(.easeInOut(duration: 0.5), value: showSuccessBanner)
//                            .onAppear {
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                                    withAnimation { showSuccessBanner = false }
//                                }
//                            }
//                    }
//                    if showClearSuccess {
//                        SuccessBanner(message: "Queue cleared and images deleted successfully!")
//                            .transition(.move(edge: .top).combined(with: .opacity))
//                            .animation(.easeInOut(duration: 0.5), value: showClearSuccess)
//                            .onAppear {
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                                    withAnimation {
//                                        showClearSuccess = false
//                                        navigateToHome = true
//                                    }
//                                }
//                            }
//                    }
//                }
//                .navigationDestination(isPresented: $navigateToHome) {
//                    HomeView().environmentObject(appData)
//                }
//                .safeAreaInset(edge: .bottom) {
//                    if areAllUploadsSuccessful {
//                        Button("Clear queue & delete all images", role: .destructive) {
//                            clearAndDeleteAllImages()
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.red)
//                        .foregroundStyle(.white)
//                        .clipShape(RoundedRectangle(cornerRadius: 10))
//                        .padding(.horizontal)
//                    } else {
//                        EmptyView()
//                    }
//                }
//                .onChange(of: uploadStatuses) { checkUploadStatus() }
//                .onAppear {
//                    uploadStatuses = Dictionary(
//                        uniqueKeysWithValues: appData.images.map { ($0.id, .idle) })
//                    if !autoUploadTriggered && areSettingsComplete {
//                        startUpload()
//                        autoUploadTriggered = true
//                    } else if !areSettingsComplete && !autoUploadTriggered {
//                        showSettingsPrompt = true
//                        autoUploadTriggered = true
//                    }
//                }
//            }
//        }
//    }
//
//    @ViewBuilder
//    func statusView(for image: CapturedImage) -> some View {
//        switch uploadStatuses[image.id] ?? .idle {
//        case .idle:
//            Text("Ready").font(.caption).foregroundStyle(.gray)
//        case .uploading(let progress):
//            ProgressView(value: progress).progressViewStyle(.linear).frame(width: 100)
//        case .success:
//            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
//        case .failure(let message):
//            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).contextMenu {
//                Text(message)
//            }
//        }
//    }
//
//    var hasFailedUploads: Bool {
//        uploadStatuses.values.contains {
//            if case .failure = $0 { return true }
//            return false
//        }
//    }
//
//    var hasActiveUploads: Bool {
//        uploadStatuses.values.contains {
//            if case .uploading = $0 { return true }
//            return false
//        }
//    }
//
//    func startUpload() {
//        for image in appData.images {
//            Task { await uploadImage(image) }
//        }
//    }
//
//    func retryFailedUploads() {
//        for image in appData.images {
//            if case .failure = uploadStatuses[image.id] {
//                Task { await uploadImage(image) }
//            }
//        }
//    }
//
//    func abortUploads() {
//        for (imageID, _) in uploadTasks {
//            uploadStatuses[imageID] = .failure("Upload aborted")
//        }
//        uploadTasks.removeAll()
//    }
//
//    func checkUploadStatus() {
//        let totalImages = appData.images.count
//        let successfulUploads = uploadStatuses.values.filter {
//            if case .success = $0 { return true }
//            return false
//        }.count
//        areAllUploadsSuccessful =
//            totalImages > 0 && successfulUploads == totalImages && !hasActiveUploads
//            && !hasFailedUploads
//        if areAllUploadsSuccessful {
//            showSuccessBanner = true
//        }
//    }
//
//    func clearAndDeleteAllImages() {
//        for image in appData.images {
//            try? FileManager.default.removeItem(at: image.fileURL)
//        }
//        appData.images.removeAll()
//        uploadStatuses.removeAll()
//        uploadTasks.removeAll()
//        areAllUploadsSuccessful = false
//        showClearSuccess = true
//    }
//
//    func uploadImage(_ image: CapturedImage) async {
//        guard let originalImage = UIImage(contentsOfFile: image.fileURL.path),
//            let imageData = originalImage.jpegData(compressionQuality: 1.0),
//            let password = appData.getPassword()
//        else {
//            await MainActor.run {
//                uploadStatuses[image.id] = .failure("Invalid image or server settings")
//                showError = true
//                errorMessage = "Check your server settings and try again."
//            }
//            return
//        }
//
//        await MainActor.run {
//            uploadStatuses[image.id] = .uploading(0)
//            uploadTasks[image.id] = true
//        }
//
//        do {
//            // Initialize SMB2Manager with URLCredential
//            let client = SMB2Manager(
//                url: URL(string: "smb://\(appData.settings.serverIP)")!,
//                credential: URLCredential(
//                    user: appData.settings.username,
//                    password: password,
//                    persistence: .forSession
//                )
//            )!
//
//            // Connect to the share
//            try await client.connectShare(name: appData.settings.shareName)
//
//            // Construct the full path, using root if targetDirectory is nil or empty
//            let targetDir =
//                appData.settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\"))
//                ?? ""
//            let destinationPath =
//                targetDir.isEmpty ? "\(image.name).jpg" : "\(targetDir)/\(image.name).jpg"
//
//            // Write the file with progress tracking, returning Bool
//            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
//                let totalSize = Double(imageData.count)
//                let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
//                DispatchQueue.main.async {
//                    uploadStatuses[image.id] = .uploading(progressFraction)
//                }
//                return true  // Continue the write operation
//            }
//
//            await MainActor.run {
//                uploadStatuses[image.id] = .success
//                uploadTasks.removeValue(forKey: image.id)
//            }
//
//            // Disconnect with try and await
//            try await client.disconnectShare()
//        } catch {
//            await MainActor.run {
//                uploadStatuses[image.id] = .failure(error.localizedDescription)
//                showError = true
//                errorMessage = error.localizedDescription
//                uploadTasks.removeValue(forKey: image.id)
//            }
//        }
//    }
//}
//
//struct SuccessBanner: View {
//    let message: String
//    var body: some View {
//        VStack {
//            Spacer()
//            Text(message)
//                .font(.headline)
//                .foregroundStyle(.white)
//                .padding()
//                .background(Color.green)
//                .clipShape(RoundedRectangle(cornerRadius: 10))
//                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
//                .frame(maxWidth: .infinity)
//                .padding(.horizontal, 20)
//        }
//        .padding(.top, 10)
//    }
//}
