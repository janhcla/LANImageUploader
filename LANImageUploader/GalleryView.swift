//
//  GalleryView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI
// On iOS, UIKit is available so we import it directly
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
    @State private var selectedImages: Set<UUID> = []
    @State private var navigateToUpload = false
    @State private var isBatchRenameUpload = false
    @State private var fullscreenData: FullscreenImageData?
    @State private var showSaveConfirmation = false
    
    private var imageNameBinding: Binding<String> {
        Binding(
            get: { self.imageName },
            set: {
                self.imageName = $0
                self.appData.imageName = $0
            }
        )
    }

    private var alertTitle: String {
        isMultiSelectMode ? "Delete Selected Images" : "Delete Selected Image"
    }

    private var alertMessage: String {
        isMultiSelectMode
            ? "Are you sure you want to delete \(selectedImages.count) image(s)?"
            : "Are you sure you want to delete this image?"
    }

    var body: some View {
        let navDestination = NavigationLink(destination: UploadView().environmentObject(appData), isActive: $navigateToUpload) { EmptyView() }
        
        return NavigationView {
            ZStack {
                navDestination
                
                // Main content
                mainContent
                    .navigationBarTitle("Gallery")
                    .navigationBarItems(
                        trailing: !appData.images.isEmpty ? Button(isMultiSelectMode ? "Done" : "Select") {
                            isMultiSelectMode.toggle()
                            if !isMultiSelectMode {
                                selectedImages.removeAll()
                            }
                        } : nil
                    )
            }
            // Apply sheet and fullScreenCover separately to reduce complexity
            .sheet(isPresented: $isShowingNamingSheet) {
                namingSheet
            }
            .fullScreenCover(item: $fullscreenData) { data in
                fullscreenView(for: data)
            }
            .overlay(
                VStack {
                    Spacer()
                    GalleryBottomActionView(
                        onSaveToArchive: saveAllToArchive,
                        onBatchRenameUpload: prepareBatchRenameUpload,
                        isEmpty: appData.images.isEmpty,
                        showSaveConfirmation: $showSaveConfirmation,
                        appData: appData
                    )
                }
            )
            .overlay(
                Group {
                    if isMultiSelectMode && !selectedImages.isEmpty && !appData.images.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Button(action: { isShowingNamingSheet = true }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(action: saveAndUpload) {
                                    Label("Save and Upload Now", systemImage: "arrow.up.circle")
                                }
                                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.8))
                        }
                    }
                }
            )
        }
    }

    // MARK: - Extracted Views

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(appData.images) { image in
                    galleryImageRow(for: image)
                }
            }
            .padding()
        }
    }

    private var namingSheet: some View {
        NamingSheet(
            imageName: imageNameBinding,
            onSave: handleNamingSave,
            saveButtonLabel: isBatchRenameUpload ? "Save & Upload" : "Save"
        )
    }

    private func fullscreenView(for data: FullscreenImageData) -> some View {
        FullscreenImageView(
            image: data.capturedImage,
            uiImage: data.uiImage,
            onDelete: {
                selectedImages = [data.capturedImage.id]
                batchDeleteImages()
                fullscreenData = nil
            },
            onSave: {
                saveSingleImageToArchive(data.capturedImage)
                showSaveConfirmation = true
            }
        )
    }

    // MARK: - Helper Methods

    private func handleImageTap(_ image: CapturedImage) {
        if !isMultiSelectMode {
            openFullscreenImage(image)
        } else {
            toggleImageSelection(image.id)
        }
    }

    private func openFullscreenImage(_ image: CapturedImage) {
        if let imageData = try? Data(contentsOf: image.fileURL),
           let uiImage = UIImage(data: imageData)
        {
            let id = UUID()
            let newData = FullscreenImageData(
                id: id,
                capturedImage: image,
                uiImage: uiImage
            )
            self.fullscreenData = newData
        }
    }

    private func toggleImageSelection(_ id: UUID) {
        if selectedImages.contains(id) {
            selectedImages.remove(id)
        } else {
            selectedImages.insert(id)
        }
    }

    private func prepareRename(_ image: CapturedImage) {
        selectedImage = image
        imageName = image.name
        appData.imageName = image.name // Sync with appData
        isShowingNamingSheet = true
    }

    private func prepareDelete(_ image: CapturedImage) {
        selectedImage = image
        selectedImages = [image.id]
        showDeleteConfirmation = true
    }

    private func saveAllToArchive() {
        appData.saveImagesToDatedFolder()
        showSaveConfirmation = true
    }

    private func prepareBatchRenameUpload() {
        selectedImages = Set(appData.images.map { $0.id })
        isBatchRenameUpload = true
        isShowingNamingSheet = true
    }

    // Helper function to handle naming sheet actions
    private func handleNamingSave() {
        // Simplified logic without complex expressions
        if isBatchRenameUpload {
            batchRenameAndUpload()
        } else if isMultiSelectMode {
            batchRenameImages()
        } else {
            renameImage()
        }
    }

    func saveSingleImageToArchive(_ image: CapturedImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let datedFolderURL = appData.documentsDirectory.appendingPathComponent(dateString)

        do {
            try FileManager.default.createDirectory(
                at: datedFolderURL, withIntermediateDirectories: true)
            let destinationURL = datedFolderURL.appendingPathComponent(
                image.fileURL.lastPathComponent)

            // Check if the image already exists in the archive
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                // Show warning that image is already saved
                DispatchQueue.main.async {
                    showSaveConfirmation = true
                    appData.scanStatus = "Image is already saved to archive."
                }
                return
            }

            try FileManager.default.copyItem(at: image.fileURL, to: destinationURL)
            print("Single image saved to \(datedFolderURL.path)")

            // Show success message
            DispatchQueue.main.async {
                showSaveConfirmation = true
                appData.scanStatus = "Image saved to archive."
            }
        } catch {
            print("Failed to save single image: \(error.localizedDescription)")
            // Show error message
            DispatchQueue.main.async {
                showSaveConfirmation = true
                appData.scanStatus = "Failed to save image: \(error.localizedDescription)"
            }
        }
    }

    func batchRenameImages() {
        guard !imageName.isEmpty else { return }
        for (index, imageID) in selectedImages.enumerated() {
            if let indexInImages = appData.images.firstIndex(where: { $0.id == imageID }) {
                let formattedIndex = String(format: "%02d", index + 1)
                appData.images[indexInImages].name = "\(imageName)\(formattedIndex)"
            }
        }
        selectedImages.removeAll()
        isMultiSelectMode = false
        imageName = ""
    }

    func saveAndUpload() {
        batchRenameImages()
        navigateToUpload = true
    }

    func batchRenameAndUpload() {
        guard !imageName.isEmpty else { return }
        for (index, imageID) in selectedImages.enumerated() {
            if let indexInImages = appData.images.firstIndex(where: { $0.id == imageID }) {
                let formattedIndex = String(format: "%02d", index + 1)
                appData.images[indexInImages].name = "\(imageName)\(formattedIndex)"
            }
        }
        selectedImages.removeAll()
        isMultiSelectMode = false
        isBatchRenameUpload = false
        imageName = ""
        navigateToUpload = true
    }

    func batchDeleteImages() {
        // Get the images to delete
        let imagesToDelete = appData.images.filter { image in
            selectedImages.contains(image.id)
        }
        
        // Delete the files from disk
        deleteImageFiles(imagesToDelete)
        
        // Then remove from the app data
        appData.images.removeAll { image in
            selectedImages.contains(image.id)
        }
        
        selectedImages.removeAll()
        isMultiSelectMode = false
        fullscreenData = nil
    }

    func deleteImageFiles(_ images: [CapturedImage]) {
        for image in images {
            try? FileManager.default.removeItem(at: image.fileURL)
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
    }

    @ViewBuilder
    func galleryImageRow(for image: CapturedImage) -> some View {
        let isSelected = selectedImages.contains(image.id)
        VStack(alignment: .center) {
            AsyncImage(url: image.fileURL) { phase in
                if let swiftUIImage = phase.image {
                    swiftUIImage
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                        .frame(maxHeight: 200)
                        .overlay(
                            isMultiSelectMode ? selectionOverlay(isSelected: isSelected) : nil
                        )
                } else if phase.error != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                }
            }
            Text(image.name)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            if !isMultiSelectMode {
                openFullscreenImage(image)
            } else {
                toggleImageSelection(image.id)
            }
        }
        .contextMenu {
            if !isMultiSelectMode {
                Button(action: { prepareRename(image) }) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive, action: { prepareDelete(image) }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    func selectionOverlay(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .blue : .gray)
            .padding(8)
            .background(Circle().fill(Color.white.opacity(0.8)))
            .offset(x: -8, y: -8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}
