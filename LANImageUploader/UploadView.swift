//
//  UploadView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import AMSMB2

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

    var areSettingsComplete: Bool {
        !appData.settings.serverIP.isEmpty &&
        !appData.settings.shareName.isEmpty &&
        !appData.settings.username.isEmpty && // Removed targetDirectory from required fields
        appData.getPassword() != nil
    }

    var body: some View {
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
                .navigationTitle("Upload Images")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if hasActiveUploads {
                            Button("Abort Upload", role: .destructive) { abortUploads() }
                        } else {
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
            .onChange(of: uploadStatuses) { checkUploadStatus() }
            .onAppear {
                uploadStatuses = Dictionary(uniqueKeysWithValues: appData.images.map { ($0.id, .idle) })
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
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).contextMenu { Text(message) }
        }
    }

    var hasFailedUploads: Bool {
        uploadStatuses.values.contains { if case .failure = $0 { return true }; return false }
    }

    var hasActiveUploads: Bool {
        uploadStatuses.values.contains { if case .uploading = $0 { return true }; return false }
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
        let successfulUploads = uploadStatuses.values.filter { if case .success = $0 { return true }; return false }.count
        areAllUploadsSuccessful = totalImages > 0 && successfulUploads == totalImages && !hasActiveUploads && !hasFailedUploads
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

    func uploadImage(_ image: CapturedImage) async {
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
            // Initialize SMB2Manager with URLCredential
            let client = SMB2Manager(
                url: URL(string: "smb://\(appData.settings.serverIP)")!,
                credential: URLCredential(
                    user: appData.settings.username,
                    password: password,
                    persistence: .forSession
                )
            )!

            // Connect to the share
            try await client.connectShare(name: appData.settings.shareName)

            // Construct the full path, using root if targetDirectory is nil or empty
            let targetDir = appData.settings.targetDirectory?.trimmingCharacters(in: .init(charactersIn: "/\\")) ?? ""
            let destinationPath = targetDir.isEmpty ? "\(image.name).jpg" : "\(targetDir)/\(image.name).jpg"

            // Write the file with progress tracking, returning Bool
            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
                let totalSize = Double(imageData.count)
                let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
                DispatchQueue.main.async {
                    uploadStatuses[image.id] = .uploading(progressFraction)
                }
                return true // Continue the write operation
            }

            await MainActor.run {
                uploadStatuses[image.id] = .success
                uploadTasks.removeValue(forKey: image.id)
            }

            // Disconnect with try and await
            try await client.disconnectShare()
        } catch {
            await MainActor.run {
                uploadStatuses[image.id] = .failure(error.localizedDescription)
                showError = true
                errorMessage = error.localizedDescription
                uploadTasks.removeValue(forKey: image.id)
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

//import SwiftUI
//import AMSMB2
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
//
//    var areSettingsComplete: Bool {
//        !appData.settings.serverIP.isEmpty &&
//        !appData.settings.shareName.isEmpty &&
//        !appData.settings.targetDirectory.isEmpty &&
//        !appData.settings.username.isEmpty &&
//        appData.getPassword() != nil
//    }
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                List(appData.images) { image in
//                    HStack {
//                        Text(image.name)
//                            .lineLimit(1)
//                        Spacer()
//                        statusView(for: image)
//                    }
//                    .padding(.vertical, 4)
//                }
//                .navigationTitle("Upload Images")
//                .toolbar {
//                    ToolbarItem(placement: .primaryAction) {
//                        if hasActiveUploads {
//                            Button("Abort Upload", role: .destructive) { abortUploads() }
//                        } else {
//                            Button("Start Upload") {
//                                if areSettingsComplete {
//                                    startUpload()
//                                } else {
//                                    showSettingsPrompt = true
//                                }
//                            }
//                        }
//                    }
//                    ToolbarItem(placement: .secondaryAction) {
//                        if hasFailedUploads {
//                            Button("Retry Failed") { retryFailedUploads() }
//                        }
//                    }
//                }
//                .alert("Upload Error", isPresented: $showError) {
//                    Button("OK", role: .cancel) {}
//                } message: {
//                    Text(errorMessage)
//                }
//                .alert("Server Settings Required", isPresented: $showSettingsPrompt) {
//                    Button("Go to Settings", role: .cancel) {}
//                    Button("Cancel") {}
//                } message: {
//                    Text("Server settings are incomplete. Uploads cannot proceed without them.")
//                }
//                if showSuccessBanner {
//                    SuccessBanner(message: "All images have been uploaded successfully!")
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                        .animation(.easeInOut(duration: 0.5), value: showSuccessBanner)
//                        .onAppear {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                                withAnimation { showSuccessBanner = false }
//                            }
//                        }
//                }
//                if showClearSuccess {
//                    SuccessBanner(message: "Queue cleared and images deleted successfully!")
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                        .animation(.easeInOut(duration: 0.5), value: showClearSuccess)
//                        .onAppear {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                                withAnimation {
//                                    showClearSuccess = false
//                                    navigateToHome = true
//                                }
//                            }
//                        }
//                }
//            }
//            .navigationDestination(isPresented: $navigateToHome) {
//                HomeView().environmentObject(appData)
//            }
//            .safeAreaInset(edge: .bottom) {
//                if areAllUploadsSuccessful {
//                    Button("Clear queue & delete all images", role: .destructive) {
//                        clearAndDeleteAllImages()
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.red)
//                    .foregroundStyle(.white)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//                    .padding(.horizontal)
//                } else {
//                    EmptyView()
//                }
//            }
//            .onChange(of: uploadStatuses) { checkUploadStatus() }
//            .onAppear {
//                uploadStatuses = Dictionary(uniqueKeysWithValues: appData.images.map { ($0.id, .idle) })
//                if !autoUploadTriggered && areSettingsComplete {
//                    startUpload()
//                    autoUploadTriggered = true
//                } else if !areSettingsComplete && !autoUploadTriggered {
//                    showSettingsPrompt = true
//                    autoUploadTriggered = true
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
//            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).contextMenu { Text(message) }
//        }
//    }
//
//    var hasFailedUploads: Bool {
//        uploadStatuses.values.contains { if case .failure = $0 { return true }; return false }
//    }
//
//    var hasActiveUploads: Bool {
//        uploadStatuses.values.contains { if case .uploading = $0 { return true }; return false }
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
//        let successfulUploads = uploadStatuses.values.filter { if case .success = $0 { return true }; return false }.count
//        areAllUploadsSuccessful = totalImages > 0 && successfulUploads == totalImages && !hasActiveUploads && !hasFailedUploads
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
//              let imageData = originalImage.jpegData(compressionQuality: 1.0),
//              let password = appData.getPassword() else {
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
//            // Construct the full path
//            let destinationPath = "\(appData.settings.targetDirectory)/\(image.name).jpg"
//
//            // Write the file with progress tracking, returning Bool
//            try await client.write(data: imageData, toPath: destinationPath) { progressBytes in
//                let totalSize = Double(imageData.count)
//                let progressFraction = totalSize > 0 ? Double(progressBytes) / totalSize : 0.0
//                DispatchQueue.main.async {
//                    uploadStatuses[image.id] = .uploading(progressFraction)
//                }
//                return true // Continue the write operation
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
