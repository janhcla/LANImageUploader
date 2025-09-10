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

    var areSettingsComplete: Bool {
        appData.isConfigured
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
        appData.clearNamingData()
        showClearSuccess = true
    }

    func uploadImage(_ image: CapturedImage, overwrite: Bool = false) async {
        guard let imageData = try? Data(contentsOf: image.fileURL) else {
            await MainActor.run {
                uploadStatuses[image.id] = .failure("Could not read image file.")
            }
            return
        }

        guard let apiKey = appData.getAPIKey(), !appData.settings.baseURL.isEmpty else {
            await MainActor.run {
                uploadStatuses[image.id] = .failure("App not paired. Please go to Settings.")
            }
            return
        }

        await MainActor.run {
            // We can't easily track URLSessionUploadTask progress as a stream,
            // so we'll just show an indeterminate progress indicator.
            uploadStatuses[image.id] = .uploading(0)
            uploadTasks[image.id] = true
        }

        let uploader = CompanionUploader()

        do {
            // Note: The new uploader doesn't support overwrite checks, as this
            // logic is now expected to be handled by the companion server.
            try await uploader.uploadImage(
                imageData: imageData,
                filename: "\(image.name).jpg",
                to: appData.settings.baseURL,
                with: apiKey
            )

            await MainActor.run {
                uploadStatuses[image.id] = .success
                uploadTasks.removeValue(forKey: image.id)
            }
        } catch {
            await MainActor.run {
                uploadStatuses[image.id] = .failure(error.localizedDescription)
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

#Preview {
    UploadView()
        .environmentObject(AppData())
}
