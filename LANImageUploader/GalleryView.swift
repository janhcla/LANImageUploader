//
//  GalleryView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
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
    @State private var selectedImages: Set<UUID> = []
    @State private var navigateToUpload = false
    @State private var isBatchRenameUpload = false
    @State private var fullscreenData: FullscreenImageData?
    @State private var showSaveConfirmation = false

    var body: some View {
        BackgroundContainerView {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appData.images) { image in
                            imageRow(for: image)
                        }
                    }
                    .padding()
                }
                .background(Color.clear)
                .navigationTitle("Gallery")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if !appData.images.isEmpty {
                            Button(isMultiSelectMode ? "Done" : "Select") {
                                isMultiSelectMode.toggle()
                                if !isMultiSelectMode {
                                    selectedImages.removeAll()
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        if isMultiSelectMode && !selectedImages.isEmpty && !appData.images.isEmpty {
                            HStack {
                                Button(action: { isShowingNamingSheet = true }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(action: saveAndUpload) {
                                    Label("Save and Upload Now", systemImage: "arrow.up.circle")
                                }
                                Button(
                                    role: .destructive, action: { showDeleteConfirmation = true }
                                ) {
                                    Label("Delete", systemImage: "trash")
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
                Button("Delete", role: .destructive) { batchDeleteImages() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    isMultiSelectMode
                        ? "Are you sure you want to delete \(selectedImages.count) image(s)?"
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
            .safeAreaInset(edge: .bottom) {
                if !appData.images.isEmpty {
                    VStack(spacing: 10) {
                        Button(action: {
                            appData.saveImagesToDatedFolder()
                            showSaveConfirmation = true
                        }) {
                            Label("Save to Archive", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button(action: {
                            selectedImages = Set(appData.images.map { $0.id })
                            isBatchRenameUpload = true
                            isShowingNamingSheet = true
                        }) {
                            Label("Batch Rename & Upload", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                } else {
                    Text("No images in gallery")
                        .foregroundStyle(.gray)
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

    @ViewBuilder
    func imageRow(for image: CapturedImage) -> some View {
        let isSelected = selectedImages.contains(image.id)
        VStack(alignment: .center) {
            AsyncImage(url: image.fileURL) { phase in
                if let swiftUIImage = phase.image {
                    swiftUIImage
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxHeight: 200)
                        .overlay {
                            if isMultiSelectMode {
                                selectionOverlay(isSelected: isSelected)
                            } else {
                                EmptyView()
                            }
                        }
                } else if phase.error != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }
            }
            Text(image.name)
                .font(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            if !isMultiSelectMode {
                if let imageData = try? Data(contentsOf: image.fileURL),
                    let uiImage = UIImage(data: imageData)
                {
                    fullscreenData = FullscreenImageData(
                        id: image.id, capturedImage: image, uiImage: uiImage)
                }
            } else {
                if selectedImages.contains(image.id) {
                    selectedImages.remove(image.id)
                } else {
                    selectedImages.insert(image.id)
                }
            }
        }
        .contextMenu {
            if !isMultiSelectMode {
                Button(action: {
                    selectedImage = image
                    imageName = image.name
                    isShowingNamingSheet = true
                }) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(
                    role: .destructive,
                    action: {
                        selectedImage = image
                        selectedImages = [image.id]
                        showDeleteConfirmation = true
                    }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    func selectionOverlay(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? .blue : .gray)
            .padding(8)
            .background(Circle().fill(Color.white.opacity(0.8)))
            .offset(x: -8, y: -8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    func saveSingleImageToArchive(_ image: CapturedImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let datedFolderURL = FileService.shared.documentsDirectory.appendingPathComponent(dateString)

        do {
            try FileService.shared.createDirectory(at: datedFolderURL)
            let destinationURL = datedFolderURL.appendingPathComponent(image.fileURL.lastPathComponent)

            // Check if the image already exists in the archive
            if FileService.shared.fileExists(at: destinationURL) {
                // Show warning that image is already saved
                showSaveConfirmation = true
                DispatchQueue.main.async {
                    showSaveConfirmation = true
                    appData.scanStatus = "Image is already saved to archive."
                }
                return
            }

            try FileService.shared.copyItem(at: image.fileURL, to: destinationURL)
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
        appData.images.removeAll { image in
            if selectedImages.contains(image.id) {
                try? FileService.shared.removeItem(at: image.fileURL)
                return true
            }
            return false
        }
        selectedImages.removeAll()
        isMultiSelectMode = false
        fullscreenData = nil
    }

    func renameImage() {
        guard let image = selectedImage,
            let index = appData.images.firstIndex(where: { $0.id == image.id })
        else { return }
        appData.images[index].name = appData.imageName.isEmpty ? "Image" : appData.imageName
        selectedImage = nil
        imageName = ""
        isShowingNamingSheet = false
    }
}

#Preview {
    GalleryView()
        .environmentObject(AppData())
}
