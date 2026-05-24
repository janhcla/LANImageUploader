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

private enum GalleryNamingIntent {
    case singleRename
    case batchRenameOnly
    case batchRenameAndUpload
}

struct GalleryView: View {
    @EnvironmentObject var appData: AppData
    @State private var isMultiSelectMode = false
    @State private var isShowingNamingSheet = false
    @State private var imageName = ""
    @State private var namingIntent: GalleryNamingIntent = .singleRename
    @State private var selectedImage: CapturedImage?
    @State private var navigateToUpload = false
    @State private var fullscreenData: FullscreenImageData?

    // Deletion states
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: GalleryItem?

    // Mode
    @State private var outputMode: GalleryOutputMode = .separateImages

    // PDF Naming
    @State private var isShowingPDFNamingSheet = false
    @State private var isGeneratingPDF = false
    @State private var pdfGenerationError: String? = nil

    // Retake logic
    @State private var retakeTargetId: UUID? = nil
    @State private var isShowingRetakeCamera = false
    @State private var retakeImage: UIImage? = nil
    @State private var isShowingRetakeReview = false

    // Grid presentation
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    // Our local source of truth for the session
    @State private var galleryItems: [GalleryItem] = []
    @State private var draggedItem: GalleryItem?

    var body: some View {
        BackgroundContainerView {
            VStack(spacing: 0) {
                if galleryItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(galleryItems.enumerated()), id: \.element.id) { index, item in
                                galleryItemCell(index: index, item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !galleryItems.isEmpty {
                        Button(isMultiSelectMode ? "Done" : "Select") {
                            appData.hapticService.playSelection()
                            withAnimation(.spring()) {
                                isMultiSelectMode.toggle()
                                if !isMultiSelectMode {
                                    appData.selectedImageIDs.removeAll()
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingNamingSheet) {
                NamingSheet(
                    imageName: $imageName,
                    title: isMultiSelectMode ? "Name Images" : "Name Your Image",
                    placeholder: "Enter name...",
                    onSave: {
                        switch namingIntent {
                        case .singleRename:
                            renameImage()
                        case .batchRenameOnly:
                            batchRenameImages()
                        case .batchRenameAndUpload:
                            batchRenameAndUpload()
                        }
                    },
                    saveButtonLabel: namingIntent == .batchRenameAndUpload ? "Save & Upload" : "Save"
                )
            }
            .sheet(isPresented: $isShowingPDFNamingSheet) {
                NamingSheet(
                    imageName: $imageName,
                    title: "Name Your PDF",
                    placeholder: "Enter PDF name...",
                    onSave: { generateAndUploadPDF() },
                    saveButtonLabel: "Create & Upload PDF"
                )
            }
            .confirmationDialog(
                "Delete Options",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let item = itemToDelete, item.capturedImage != nil {
                    Button("Leave Empty Space", role: .destructive) {
                        leaveEmptySpace(item)
                    }
                }
                Button("Delete Space", role: .destructive) {
                    if let item = itemToDelete { deleteSpace(item) }
                }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            } message: {
                Text("What would you like to do?")
            }
            .fullScreenCover(item: $fullscreenData) { data in
                FullscreenImageView(
                    image: data.capturedImage,
                    uiImage: data.uiImage,
                    onDelete: {
                        if let item = galleryItems.first(where: { $0.id == data.id }) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        }
                        fullscreenData = nil
                    },
                    onSave: { }
                )
            }
            .fullScreenCover(isPresented: $isShowingRetakeCamera, onDismiss: {
                if retakeImage != nil {
                    isShowingRetakeReview = true
                } else {
                    retakeTargetId = nil
                }
            }) {
                CameraPickerWrapper(image: $retakeImage)
            }
            .sheet(isPresented: $isShowingRetakeReview) {
                if let newImage = retakeImage {
                    RetakeReviewSheet(
                        newImage: newImage,
                        onUseNew: {
                            Task { await completeRetake(with: newImage) }
                        },
                        onDiscard: {
                            retakeImage = nil
                            retakeTargetId = nil
                            isShowingRetakeReview = false
                        },
                        onRetakeAgain: {
                            retakeImage = nil
                            isShowingRetakeReview = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isShowingRetakeCamera = true
                            }
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToUpload) {
                UploadView().environmentObject(appData)
            }
            .safeAreaInset(edge: .bottom) {
                if isMultiSelectMode && !appData.selectedImageIDs.isEmpty {
                    MultiSelectToolbarView(
                        appData: appData,
                        onUpload: uploadSelectedItems,
                        onDelete: deleteSelectedItems,
                        onRename: {
                            imageName = ""
                            namingIntent = .batchRenameOnly
                            isShowingNamingSheet = true
                        },
                        onRotate: rotateSelectedItems,
                        onArchive: archiveSelectedItems
                    )
                } else if !galleryItems.isEmpty && !isMultiSelectMode {
                    GlassContainer(cornerRadius: 20) {
                        VStack(spacing: 12) {
                            Picker("Output Mode", selection: $outputMode) {
                                ForEach(GalleryOutputMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 16) {
                                if outputMode == .separateImages {
                                    Button(action: uploadAllItems) {
                                        Label("Upload", systemImage: "square.and.arrow.up")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(GrayButtonStyle())

                                    Button(action: {
                                        appData.selectedImageIDs = Set(galleryItems.compactMap { $0.capturedImage?.id })
                                        namingIntent = .batchRenameAndUpload
                                        isShowingNamingSheet = true
                                    }) {
                                        Label("Batch Rename & Upload", systemImage: "square.and.pencil")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(OrangeButtonStyle())
                                } else {
                                    Button(action: {
                                        isShowingPDFNamingSheet = true
                                    }) {
                                        Label("Create PDF & Upload", systemImage: "doc.text")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(OrangeButtonStyle())
                                }
                            }
                            .disabled(isGeneratingPDF)
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .alert("Error", isPresented: Binding(get: { pdfGenerationError != nil }, set: { if !$0 { pdfGenerationError = nil } })) {
                Button("OK") { pdfGenerationError = nil }
            } message: {
                Text(pdfGenerationError ?? "Unknown error occurred.")
            }
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("Generating PDF...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .onAppear {
            syncItemsFromAppData()
            outputMode = appData.defaultGalleryOutputMode
        }
        .onChange(of: appData.images.map(\.id)) { _, _ in
            syncItemsFromAppData()
        }
    }

    @ViewBuilder
    private func galleryItemCell(index: Int, item: GalleryItem) -> some View {
        GalleryItemView(
            index: index,
            item: item,
            isSelected: isMultiSelectMode && appData.selectedImageIDs.contains(item.id),
            isMultiSelectMode: isMultiSelectMode,
            onTap: { handleItemTap(item) },
            onUpload: { uploadItems([item]) },
            onRotate: { rotateItem(item) },
            onDelete: {
                itemToDelete = item
                showDeleteConfirmation = true
            },
            onRetake: {
                retakeTargetId = item.id
                isShowingRetakeCamera = true
            }
        )
        .opacity(draggedItem?.id == item.id ? 0.55 : 1)
        .onDrag {
            guard !isMultiSelectMode else {
                return NSItemProvider()
            }
            draggedItem = item
            appData.hapticService.playImpact(style: .light)
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: ReorderDropDelegate(item: item, items: $galleryItems, draggedItem: $draggedItem)
        )
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

    func handleItemTap(_ item: GalleryItem) {
        if !isMultiSelectMode {
            guard let image = item.capturedImage else { return }
            appData.hapticService.playSelection()
            if let imageData = try? Data(contentsOf: image.fileURL),
                let uiImage = UIImage(data: imageData)
            {
                fullscreenData = FullscreenImageData(
                    id: image.id, capturedImage: image, uiImage: uiImage)
            }
        } else {
            if appData.selectedImageIDs.contains(item.id) {
                appData.selectedImageIDs.remove(item.id)
            } else {
                appData.hapticService.playImpact(style: .light)
                appData.selectedImageIDs.insert(item.id)
            }
        }
    }

    func rotateItem(_ item: GalleryItem) {
        Task {
            await rotateAndPersistItems(withIDs: Set([item.id]))
        }
    }

    func uploadAllItems() {
        uploadItems(galleryItems)
    }

    func uploadSelectedItems() {
        let selectedIDs = appData.selectedImageIDs
        let selectedItems = galleryItems.filter { selectedIDs.contains($0.id) }
        uploadItems(selectedItems)
    }

    func uploadItems(_ items: [GalleryItem]) {
        let itemsToUpload = items.filter { $0.capturedImage != nil }
        guard !itemsToUpload.isEmpty else { return }

        Task {
            await applyRotationsBeforeUpload()
            await MainActor.run {
                appData.pendingUploadFiles = itemsToUpload.compactMap { item in
                    guard let image = item.capturedImage else { return nil }
                    return UploadableFile(
                        id: image.id,
                        name: image.name,
                        fileURL: image.fileURL,
                        kind: .jpeg
                    )
                }
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                navigateToUpload = true
            }
        }
    }

    func leaveEmptySpace(_ item: GalleryItem) {
        guard let idx = galleryItems.firstIndex(where: { $0.id == item.id }) else { return }
        deleteLocalImage(item.capturedImage)
        galleryItems[idx].capturedImage = nil
        galleryItems[idx].rotation = .degrees0
        itemToDelete = nil
    }

    func deleteSpace(_ item: GalleryItem) {
        guard let idx = galleryItems.firstIndex(where: { $0.id == item.id }) else { return }
        deleteLocalImage(item.capturedImage)
        galleryItems.remove(at: idx)
        itemToDelete = nil
    }

    private func deleteLocalImage(_ capturedImage: CapturedImage?) {
        guard let img = capturedImage else { return }
        Task {
            try? await appData.fileService.removeItem(at: img.fileURL)
            await MainActor.run {
                appData.images.removeAll(where: { $0.id == img.id })
            }
        }
    }

    func deleteSelectedItems() {
        let selectedIDs = appData.selectedImageIDs
        guard !selectedIDs.isEmpty else { return }

        let imagesToDelete = galleryItems.compactMap { item -> CapturedImage? in
            guard selectedIDs.contains(item.id) else { return nil }
            return item.capturedImage
        }

        galleryItems.removeAll { selectedIDs.contains($0.id) }
        appData.selectedImageIDs.removeAll()
        isMultiSelectMode = false

        Task {
            for image in imagesToDelete {
                try? await appData.fileService.removeItem(at: image.fileURL)
            }
            await MainActor.run {
                appData.images.removeAll { image in
                    imagesToDelete.contains { $0.id == image.id }
                }
                appData.hapticService.playNotification(type: .success)
            }
        }
    }

    func rotateSelectedItems() {
        Task {
            await rotateAndPersistItems(withIDs: appData.selectedImageIDs)
        }
    }

    func archiveSelectedItems() {
        let selectedImages = galleryItems.compactMap { item -> CapturedImage? in
            guard appData.selectedImageIDs.contains(item.id) else { return nil }
            return item.capturedImage
        }

        guard !selectedImages.isEmpty else { return }

        Task {
            await appData.saveImagesToDatedFolder(selectedImages)
            await MainActor.run {
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                appData.hapticService.playNotification(type: .success)
            }
        }
    }

    @MainActor
    private func rotateAndPersistItems(withIDs ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }

        var rotatedAny = false
        for id in ids {
            guard let itemIndex = galleryItems.firstIndex(where: { $0.id == id }),
                  let image = galleryItems[itemIndex].capturedImage
            else { continue }

            galleryItems[itemIndex].rotation = galleryItems[itemIndex].rotation.nextClockwise
            let rotation = galleryItems[itemIndex].rotation

            do {
                try await persistRotation(for: image, rotation: rotation)
                if let appIndex = appData.images.firstIndex(where: { $0.id == image.id }) {
                    appData.images[appIndex].fileURL = image.fileURL
                }
                galleryItems[itemIndex].rotation = .degrees0
                rotatedAny = true
            } catch {
                galleryItems[itemIndex].rotation = .degrees0
                pdfGenerationError = "Failed to rotate image: \(error.localizedDescription)"
            }
        }

        if rotatedAny {
            appData.hapticService.playImpact(style: .light)
        }
    }

    private func persistRotation(for image: CapturedImage, rotation: ImageRotation) async throws {
        guard rotation != .degrees0 else { return }
        guard let uiImage = UIImage(contentsOfFile: image.fileURL.path) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let rotated = uiImage.rotatedClockwise(by: rotation)
        guard let data = rotated.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        _ = try await appData.fileService.saveImage(data, fileName: image.fileURL.lastPathComponent)
    }

    func completeRetake(with image: UIImage) async {
        guard let targetId = retakeTargetId,
              let idx = galleryItems.firstIndex(where: { $0.id == targetId }) else {
            await MainActor.run {
                retakeImage = nil
                retakeTargetId = nil
                isShowingRetakeReview = false
            }
            return
        }

        do {
            let captured = try await appData.saveCapturedUIImage(image, suggestedPrefix: "RETAKE")
            await MainActor.run {
                deleteLocalImage(galleryItems[idx].capturedImage)
                galleryItems[idx] = GalleryItem(id: captured.id, capturedImage: captured, rotation: .degrees0)
                appData.images.append(captured)
                retakeImage = nil
                retakeTargetId = nil
                isShowingRetakeReview = false
            }
        } catch {
            await MainActor.run {
                retakeImage = nil
                retakeTargetId = nil
                isShowingRetakeReview = false
            }
        }
    }

    @MainActor
    private func renameSelectedImagesInGalleryOrder(baseName: String) -> [UploadableFile] {
        let selectedIDs = appData.selectedImageIDs
        let orderedItems = galleryItems.filter { item in
            selectedIDs.contains(item.id) && item.capturedImage != nil
        }

        var uploadFiles: [UploadableFile] = []
        for (index, item) in orderedItems.enumerated() {
            guard let image = item.capturedImage,
                  let appIndex = appData.images.firstIndex(where: { $0.id == image.id })
            else { continue }

            let formattedIndex = String(format: "%02d", index + 1)
            let renamedImage = "\(baseName)\(formattedIndex)"
            appData.images[appIndex].name = renamedImage
            uploadFiles.append(
                UploadableFile(
                    id: image.id,
                    name: renamedImage,
                    fileURL: appData.images[appIndex].fileURL,
                    kind: .jpeg
                )
            )
        }

        return uploadFiles
    }

    func batchRenameImages() {
        guard !imageName.isEmpty else { return }
        _ = renameSelectedImagesInGalleryOrder(baseName: imageName)
        appData.selectedImageIDs.removeAll()
        isMultiSelectMode = false
        imageName = ""
        appData.hapticService.playNotification(type: .success)
    }

    func batchRenameAndUpload() {
        guard !imageName.isEmpty else { return }

        Task {
            await applyRotationsBeforeUpload()
            await MainActor.run {
                appData.pendingUploadFiles = renameSelectedImagesInGalleryOrder(baseName: imageName)
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                imageName = ""
                navigateToUpload = true
            }
        }
    }

    func applyRotationsBeforeUpload() async {
        for item in galleryItems {
            guard let img = item.capturedImage, item.rotation != .degrees0 else { continue }
            guard let idx = appData.images.firstIndex(where: { $0.id == img.id }) else { continue }

            do {
                try await persistRotation(for: img, rotation: item.rotation)
                await MainActor.run {
                    appData.images[idx].fileURL = img.fileURL
                    if let galleryIdx = galleryItems.firstIndex(where: { $0.id == item.id }) {
                        galleryItems[galleryIdx].rotation = .degrees0
                    }
                }
            } catch {
                await MainActor.run {
                    pdfGenerationError = "Failed to rotate image before upload: \(error.localizedDescription)"
                }
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
    }

    func generateAndUploadPDF() {
        guard !imageName.isEmpty else { return }
        isGeneratingPDF = true

        let settings = PDFSettings(
            pageSize: appData.pdfPageSize,
            imageLayout: appData.pdfImageLayout,
            includePageNumbers: appData.pdfIncludePageNumbers,
            jpegQuality: CGFloat(appData.pdfJPEGQuality),
            margin: 24,
            maxPixelDimension: CGFloat(appData.imageMaxPixelDimension)
        )

        let itemsToProcess = galleryItems
        let finalName = imageName

        Task {
            do {
                let pdfURL = try await PDFGenerationService.shared.generatePDF(
                    from: itemsToProcess,
                    outputName: finalName,
                    settings: settings
                )

                let uploadFile = UploadableFile(
                    id: UUID(),
                    name: finalName,
                    fileURL: pdfURL,
                    kind: .pdf
                )

                await MainActor.run {
                    appData.pendingUploadFiles = [uploadFile]
                    isGeneratingPDF = false
                    isShowingPDFNamingSheet = false
                    imageName = ""
                    navigateToUpload = true
                }
            } catch {
                await MainActor.run {
                    isGeneratingPDF = false
                    pdfGenerationError = error.localizedDescription
                }
            }
        }
    }

    private func syncItemsFromAppData() {
        let appDataIDs = Set(appData.images.map { $0.id })
        var updatedItems = galleryItems.filter { item in
            if let image = item.capturedImage {
                return appDataIDs.contains(image.id)
            }
            return true
        }

        let existingImageIDs = Set(updatedItems.compactMap { $0.capturedImage?.id })
        for image in appData.images where !existingImageIDs.contains(image.id) {
            updatedItems.append(GalleryItem(id: image.id, capturedImage: image, rotation: .degrees0))
        }

        galleryItems = updatedItems
    }
}

struct ReorderDropDelegate: DropDelegate {
    let item: GalleryItem
    @Binding var items: [GalleryItem]
    @Binding var draggedItem: GalleryItem?

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem else { return }
        guard dragged.id != item.id else { return }

        if let fromIndex = items.firstIndex(of: dragged),
           let toIndex = items.firstIndex(of: item) {
            withAnimation(.default) {
                self.items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
