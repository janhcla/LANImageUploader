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
        // Standard NavigationView for consistent title placement
        NavigationStack {
            VStack(spacing: 0) {
                // Main content
                if appData.images.isEmpty {
                    VStack {
                        Spacer()
                        Text("No images in gallery")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(appData.images) { image in
                                galleryImageRow(for: image)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()  // Push content to the top

                // Bottom buttons only if there are images
                if !appData.images.isEmpty {
                    // Only show these buttons when not in multi-select mode or when no selection
                    if !isMultiSelectMode || selectedImages.isEmpty {
                        VStack(spacing: 10) {
                            // Gray button for Save to Archive
                            Button(action: {
                                appData.saveImagesToDatedFolder()
                                showSaveConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 18))
                                    Text("Save to Archive")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                            // Orange button for Batch Rename & Upload
                            Button(action: {
                                selectedImages = Set(appData.images.map { $0.id })
                                isBatchRenameUpload = true
                                isShowingNamingSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 18))
                                    Text("Batch Rename & Upload")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
            }
            // Use navigationTitle for consistent positioning
            .navigationTitle("Gallery")
            // Use standard toolbar implementation that works with NavigationStack
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appData.images.isEmpty {
                        Button(isMultiSelectMode ? "Done" : "Select") {
                            isMultiSelectMode.toggle()
                            if !isMultiSelectMode {
                                selectedImages.removeAll()
                            }
                        }
                    }
                }
            }

            // Selection overlay for multi-select mode with selected images
            .overlay(
                Group {
                    if isMultiSelectMode && !selectedImages.isEmpty {
                        VStack {
                            Spacer()  // Push to bottom
                            // Action buttons without visible container
                            HStack(spacing: 30) {
                                // Rename button
                                Button(action: { isShowingNamingSheet = true }) {
                                    VStack {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 24))
                                        Text("Rename")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }

                                // Save and Upload Now button
                                Button(action: saveAndUpload) {
                                    VStack {
                                        Image(systemName: "arrow.up.circle")
                                            .font(.system(size: 24))
                                        Text("Upload")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }

                                // Delete button
                                Button(action: {
                                    showDeleteConfirmation = true
                                }) {
                                    VStack {
                                        Image(systemName: "trash")
                                            .font(.system(size: 24))
                                        Text("Delete")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                            .padding()
                            // No background or shadow to make the box invisible
                            .padding(.bottom, 8)
                        }
                    }
                }
            )

            // Modals and alerts
            .sheet(isPresented: $isShowingNamingSheet) {
                NamingSheet(
                    imageName: imageNameBinding,
                    onSave: handleNamingSave,
                    saveButtonLabel: isBatchRenameUpload ? "Save & Upload" : "Save"
                )
            }
            .alert(alertTitle, isPresented: $showDeleteConfirmation) {
                Alert.Button.destructive(Text("Delete"), action: batchDeleteImages)
                Alert.Button.cancel()
            } message: {
                Text(alertMessage)
            }
            .alert("Confirmation", isPresented: $showSaveConfirmation) {
                Alert.Button.default(Text("OK"))
            } message: {
                Text(
                    appData.scanStatus.isEmpty
                        ? "Images saved to the app archive" : appData.scanStatus)
            }
            .fullScreenCover(item: $fullscreenData) { data in
                fullscreenView(for: data)
            }
            .navigationDestination(isPresented: $navigateToUpload) {
                UploadView().environmentObject(appData)
            }
        }
        // Remove the navigationViewStyle as it's not needed with NavigationStack
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

    private func openFullscreenImage(_ image: CapturedImage) {
        if let imageData = try? Data(contentsOf: image.fileURL),
            let uiImage = UIImage(data: imageData)
        {
            self.fullscreenData = FullscreenImageData(
                id: UUID(),
                capturedImage: image,
                uiImage: uiImage
            )
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
        appData.imageName = image.name
        isShowingNamingSheet = true
    }

    private func prepareDelete(_ image: CapturedImage) {
        selectedImage = image
        selectedImages = [image.id]
        showDeleteConfirmation = true
    }

    private func handleNamingSave() {
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

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                DispatchQueue.main.async {
                    showSaveConfirmation = true
                    appData.scanStatus = "Image is already saved to archive."
                }
                return
            }

            try FileManager.default.copyItem(at: image.fileURL, to: destinationURL)
            print("Single image saved to \(datedFolderURL.path)")

            DispatchQueue.main.async {
                showSaveConfirmation = true
                appData.scanStatus = "Image saved to archive."
            }
        } catch {
            print("Failed to save single image: \(error.localizedDescription)")
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
        // Rename images if needed
        batchRenameImages()

        // Force navigation with a delay to ensure state update is processed
        DispatchQueue.main.async {
            self.navigateToUpload = true
        }

        // Print debug message
        print("Navigating to upload view: navigateToUpload = \(navigateToUpload)")
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
        let imagesToDelete = appData.images.filter { image in
            selectedImages.contains(image.id)
        }

        deleteImageFiles(imagesToDelete)

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
                // Save image to archive
                saveSingleImageToArchive(data.capturedImage)
                // Set confirmation message - the dismiss is handled in the button now
                DispatchQueue.main.async {
                    // Wait briefly for the view to dismiss before showing alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appData.scanStatus = "Image saved to archive."
                        showSaveConfirmation = true
                    }
                }
                // The fullscreenData is nil'd by dismiss() in the FullscreenImageView
            }
        )
    }
}
