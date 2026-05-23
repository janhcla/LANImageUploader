//
//  GalleryView.swift
//  LANImageUploader
//

import SwiftUI
import UIKit

struct FullscreenImageData: Identifiable {
    let id: UUID
    let capturedImage: CapturedImage
    let uiImage: UIImage
}

struct GalleryView: View {
    @EnvironmentObject var appData: AppData
    @State private var isShowingNamingSheet = false
    @State private var imageName = ""
    @State private var selectedImage: CapturedImage?
    @State private var showDeleteConfirmation = false
    @State private var isMultiSelectMode = false
    @State private var navigateToUpload = false
    @State private var isBatchRenameUpload = false
    @State private var fullscreenData: FullscreenImageData?
    @State private var showSaveConfirmation = false

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        BackgroundContainerView {
            NavigationStack {
                ZStack {
                    ScrollView {
                        if appData.images.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(appData.images) { image in
                                    ImageRowView(
                                        image: image,
                                        isMultiSelectMode: isMultiSelectMode,
                                        isSelected: appData.selectedImageIDs.contains(image.id),
                                        onTap: { handleImageTap(image) },
                                        onRename: {
                                            selectedImage = image
                                            imageName = image.name
                                            isShowingNamingSheet = true
                                        },
                                        onDelete: {
                                            selectedImage = image
                                            appData.selectedImageIDs = [image.id]
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                            .padding()
                            .padding(.bottom, 100) // Space for toolbar
                        }
                    }
                    
                    // Multi-select Toolbar
                    if isMultiSelectMode && !appData.selectedImageIDs.isEmpty {
                        VStack {
                            Spacer()
                            MultiSelectToolbarView(
                                appData: appData,
                                onDelete: { showDeleteConfirmation = true },
                                onRename: { isShowingNamingSheet = true },
                                onArchive: {
                                    Task {
                                        let selectedImages = appData.images.filter { appData.selectedImageIDs.contains($0.id) }
                                        await appData.saveImagesToDatedFolder(selectedImages)
                                        showSaveConfirmation = true
                                        isMultiSelectMode = false
                                        appData.selectedImageIDs.removeAll()
                                    }
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .navigationTitle("Gallery")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if !appData.images.isEmpty {
                            Button(isMultiSelectMode ? "Done" : "Select") {
                                appData.hapticService.playSelection()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMultiSelectMode.toggle()
                                    if !isMultiSelectMode {
                                        appData.selectedImageIDs.removeAll()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingNamingSheet) {
                NamingSheet(
                    imageName: $imageName,
                    onSave: isBatchRenameUpload
                        ? batchRenameAndUpload
                        : (isMultiSelectMode ? batchRenameImages : renameImage),
                    saveButtonLabel: isBatchRenameUpload ? "Save & Upload" : "Save"
                )
            }
            .alert(
                isMultiSelectMode ? "Delete Selected Images" : "Delete Selected Image",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) { 
                    Task { 
                        await appData.deleteSelectedImages() 
                        isMultiSelectMode = false
                    }
                }
                Button("Cancel", role: .cancel) {
                    if !isMultiSelectMode { appData.selectedImageIDs.removeAll() }
                }
            } message: {
                Text(
                    isMultiSelectMode
                        ? "Are you sure you want to delete \(appData.selectedImageIDs.count) image(s)?"
                        : "Are you sure you want to delete this image?")
            }
            .navigationDestination(isPresented: $navigateToUpload) {
                UploadView().environmentObject(appData)
            }
            .fullScreenCover(item: $fullscreenData) { data in
                FullscreenImageView(
                    image: data.capturedImage,
                    uiImage: data.uiImage,
                    onDelete: {
                        appData.selectedImageIDs = [data.capturedImage.id]
                        Task { await appData.deleteSelectedImages() }
                        fullscreenData = nil
                    },
                    onSave: {
                        Task { await saveSingleImageToArchive(data.capturedImage) }
                        showSaveConfirmation = true
                    }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if !appData.images.isEmpty && !isMultiSelectMode {
                    GlassContainer(cornerRadius: 20) {
                        HStack(spacing: 16) {
                            Button(action: {
                                Task { await appData.saveImagesToDatedFolder() }
                                showSaveConfirmation = true
                            }) {
                                Label("Archive All", systemImage: "square.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(GrayButtonStyle())
                            
                            Button(action: {
                                appData.selectedImageIDs = Set(appData.images.map { $0.id })
                                isBatchRenameUpload = true
                                isShowingNamingSheet = true
                            }) {
                                Label("Batch Upload", systemImage: "square.and.pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(OrangeButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .alert("Confirmation", isPresented: $showSaveConfirmation) {
                Button("OK") { showSaveConfirmation = false }
            } message: {
                Text(
                    appData.scanStatus.isEmpty
                        ? "Images saved to the app archive" : appData.scanStatus)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
            Text("No images in gallery")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    func handleImageTap(_ image: CapturedImage) {
        if !isMultiSelectMode {
            appData.hapticService.playSelection()
            if let imageData = try? Data(contentsOf: image.fileURL),
                let uiImage = UIImage(data: imageData)
            {
                fullscreenData = FullscreenImageData(
                    id: image.id, capturedImage: image, uiImage: uiImage)
            }
        } else {
            if appData.selectedImageIDs.contains(image.id) {
                appData.selectedImageIDs.remove(image.id)
            } else {
                appData.hapticService.playImpact(style: .light)
                appData.selectedImageIDs.insert(image.id)
            }
        }
    }

    func saveSingleImageToArchive(_ image: CapturedImage) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let docs = await appData.fileService.documentsDirectory
        let datedFolderURL = docs.appendingPathComponent(dateString)

        do {
            try await appData.fileService.createDirectory(at: datedFolderURL)
            let destinationURL = datedFolderURL.appendingPathComponent(image.fileURL.lastPathComponent)

            if await appData.fileService.fileExists(at: destinationURL) {
                await MainActor.run {
                    showSaveConfirmation = true
                    appData.scanStatus = "Image is already saved to archive."
                }
                return
            }

            try await appData.fileService.copyItem(at: image.fileURL, to: destinationURL)
            
            await MainActor.run {
                showSaveConfirmation = true
                appData.scanStatus = "Image saved to archive."
                appData.hapticService.playNotification(type: .success)
            }
        } catch {
            await MainActor.run {
                showSaveConfirmation = true
                appData.scanStatus = "Failed to save image: \(error.localizedDescription)"
            }
        }
    }

    private func performBatchRename() async {
        let baseName = imageName
        let targetIDs = appData.selectedImageIDs
        let currentImages = appData.images

        let renamedTuples = await withTaskGroup(of: (Int, String)?.self) { group in
            var selectedCount = 0
            for i in currentImages.indices {
                if targetIDs.contains(currentImages[i].id) {
                    let currentCount = selectedCount + 1
                    group.addTask {
                        let formattedIndex = String(format: "%02d", currentCount)
                        return (i, "\(baseName)\(formattedIndex)")
                    }
                    selectedCount += 1
                }
            }

            var results: [(Int, String)] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }

        await MainActor.run {
            for (index, newName) in renamedTuples {
                appData.images[index].name = newName
            }
            appData.selectedImageIDs.removeAll()
            isMultiSelectMode = false
            imageName = ""
        }
    }

    func batchRenameImages() {
        guard !imageName.isEmpty else { return }
        Task {
            await performBatchRename()
            await MainActor.run {
                appData.hapticService.playNotification(type: .success)
            }
        }
    }
    func batchRenameAndUpload() {
        guard !imageName.isEmpty else { return }
        Task {
            await performBatchRename()
            await MainActor.run {
                isBatchRenameUpload = false
                navigateToUpload = true
            }
        }
    }
    func renameImage() {
        guard let image = selectedImage,
            let index = appData.images.firstIndex(where: { $0.id == image.id })
        else { return }
        appData.images[index].name = imageName.isEmpty ? "Image" : imageName
        selectedImage = nil
        imageName = ""
        isShowingNamingSheet = false
        appData.hapticService.playNotification(type: .success)
    }
}

#Preview {
    GalleryView()
        .environmentObject(AppData.preview)
}