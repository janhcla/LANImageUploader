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

private struct RetakeReviewData: Identifiable {
    let id = UUID()
    let image: UIImage
}

private enum GalleryNamingIntent {
    case singleRename
    case batchRenameOnly
    case batchRenameAndUpload
}

private struct GalleryExportRequest: Sendable {
    let order: Int
    let image: CapturedImage
    let name: String
}

@MainActor
final class GalleryOperationGate: ObservableObject {
    private var activeOperationID: UUID?

    func begin() -> UUID {
        let operationID = UUID()
        activeOperationID = operationID
        return operationID
    }

    func cancel() {
        activeOperationID = nil
    }

    func isCurrent(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    @discardableResult
    func finish(_ operationID: UUID) -> Bool {
        guard activeOperationID == operationID else { return false }
        activeOperationID = nil
        return true
    }
}

struct GalleryView: View {
    let initialOutputMode: GalleryOutputMode?
    @EnvironmentObject var appData: AppData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isMultiSelectMode = false
    @State private var isShowingNamingSheet = false
    @State private var imageName = ""
    @State private var namingIntent: GalleryNamingIntent = .singleRename
    @State private var selectedImage: CapturedImage?
    @State private var navigateToUpload = false
    @State private var fullscreenData: FullscreenImageData?
    @State private var isLoadingFullscreen = false
    @State private var cropEditingItem: GalleryItem?

    // Deletion states
    @State private var showDeleteConfirmation = false
    @State private var showBatchDeleteConfirmation = false
    @State private var itemToDelete: GalleryItem?
    @State private var emptyStateCameraMode: CameraCaptureMode?

    // Mode
    @State private var outputMode: GalleryOutputMode

    // PDF Naming
    @State private var isShowingPDFNamingSheet = false
    @State private var isGeneratingPDF = false
    @State private var pdfGenerationTask: Task<Void, Never>?
    @State private var isPreparingUpload = false
    @State private var preparationTask: Task<Void, Never>?
    @StateObject private var pdfOperationGate = GalleryOperationGate()
    @StateObject private var preparationOperationGate = GalleryOperationGate()
    @State private var pdfGenerationError: String? = nil

    // Retake logic
    @State private var retakeTargetId: UUID? = nil
    @State private var isShowingRetakeCamera = false
    @State private var retakeImage: UIImage? = nil
    @State private var retakeReviewData: RetakeReviewData?
    @State private var retakeError: String?

    // Grid presentation
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    // Our local source of truth for the session
    @State private var galleryItems: [GalleryItem] = []
    @State private var draggedItem: GalleryItem?

    init(initialOutputMode: GalleryOutputMode? = nil) {
        self.initialOutputMode = initialOutputMode
        _outputMode = State(initialValue: initialOutputMode ?? .separateImages)
    }

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
                            withAnimation(reduceMotion ? nil : .spring()) {
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
                "Delete Image?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let item = itemToDelete, item.capturedImage != nil {
                    Button("Delete Image, Keep Placeholder", role: .destructive) {
                        leaveEmptySpace(item)
                    }
                }
                Button("Delete Image and Close Gap", role: .destructive) {
                    if let item = itemToDelete { deleteSpace(item) }
                }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            } message: {
                Text("Keep a placeholder to preserve this page position, or close the gap and renumber the remaining items.")
            }
            .confirmationDialog(
                "Delete Selected Images?",
                isPresented: $showBatchDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(appData.selectedImageIDs.count) Images", role: .destructive) {
                    deleteSelectedItems()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected local images will be permanently removed from Gallery.")
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
                    onSave: nil
                )
            }
            .fullScreenCover(item: $emptyStateCameraMode) { mode in
                CameraView(initialMode: mode)
                    .environmentObject(appData)
            }
            .sheet(item: $cropEditingItem) { item in
                if let capturedImage = item.capturedImage,
                   let source = UIImage(contentsOfFile: capturedImage.fileURL.path) {
                    CropEditorView(
                        sourceImage: source,
                        initialCrop: capturedImage.crop ?? .fullFrame,
                        onCancel: { cropEditingItem = nil },
                        onSave: { crop in
                            appData.updateCrop(for: capturedImage.id, crop: crop)
                            if let index = galleryItems.firstIndex(where: { $0.id == capturedImage.id }) {
                                galleryItems[index].capturedImage?.crop = crop
                                galleryItems[index].capturedImage?.isDocumentScan = true
                            }
                            cropEditingItem = nil
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $isShowingRetakeCamera, onDismiss: {
                if let retakeImage {
                    DispatchQueue.main.async {
                        retakeReviewData = RetakeReviewData(image: retakeImage)
                    }
                } else {
                    retakeTargetId = nil
                }
            }) {
                CameraPickerWrapper(image: $retakeImage)
            }
            .sheet(item: $retakeReviewData, onDismiss: clearRetakeState) { data in
                RetakeReviewSheet(
                    newImage: data.image,
                    onUseNew: {
                        Task { await completeRetake(with: data.image) }
                    },
                    onDiscard: {
                        retakeImage = nil
                        retakeTargetId = nil
                        retakeReviewData = nil
                    },
                    onRetakeAgain: {
                        retakeImage = nil
                        retakeReviewData = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isShowingRetakeCamera = true
                        }
                    }
                )
            }
            .alert("Retake failed", isPresented: Binding(
                get: { retakeError != nil },
                set: { if !$0 { retakeError = nil } }
            )) {
                Button("OK") { retakeError = nil }
            } message: {
                Text(retakeError ?? "The original image was kept. Please try again.")
            }
            .navigationDestination(isPresented: $navigateToUpload) {
                UploadView(fallbackToGalleryImages: false, automaticallyStarts: true)
                    .environmentObject(appData)
            }
            .safeAreaInset(edge: .bottom) {
                if isMultiSelectMode && !appData.selectedImageIDs.isEmpty {
                    MultiSelectToolbarView(
                        appData: appData,
                        onUpload: uploadSelectedItemsForCurrentOutputMode,
                        onDelete: { showBatchDeleteConfirmation = true },
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
                                        Label("Rename & Upload", systemImage: "square.and.pencil")
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
                            .disabled(isGeneratingPDF || isPreparingUpload)
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .alert("Error", isPresented: Binding(get: { pdfGenerationError != nil }, set: { if !$0 { pdfGenerationError = nil } })) {
                Button("OK") { pdfGenerationError = nil }
            } message: {
                Text(pdfGenerationError ?? "PDF generation failed. Please try again.")
            }
            .overlay {
                if isGeneratingPDF || isPreparingUpload {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView(isGeneratingPDF ? "Generating PDF..." : "Preparing upload...")
                            Button("Cancel", role: .cancel) {
                                cancelProcessing()
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        }
                    }
                }
            }
            .overlay {
                if isLoadingFullscreen {
                    ZStack {
                        Color.black.opacity(0.24).ignoresSafeArea()
                        ProgressView("Loading image...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
        .onAppear {
            syncItemsFromAppData()
            outputMode = initialOutputMode ?? appData.defaultGalleryOutputMode
        }
        .onChange(of: gallerySyncTokens) { _, _ in
            syncItemsFromAppData()
        }
    }

    private var gallerySyncTokens: [String] {
        appData.images.map { image in
            "\(image.id.uuidString)|\(image.name)|\(image.fileURL.path)|\(String(describing: image.crop))|\(image.rotation.rawValue)"
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
            onEditCrop: { cropEditingItem = item },
            onDelete: {
                itemToDelete = item
                showDeleteConfirmation = true
            },
            onRename: {
                guard let image = item.capturedImage else { return }
                selectedImage = image
                imageName = image.name
                namingIntent = .singleRename
                isShowingNamingSheet = true
            },
            onRetake: {
                retakeTargetId = item.id
                isShowingRetakeCamera = true
            }
        )
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
            delegate: ReorderDropDelegate(
                item: item,
                items: $galleryItems,
                draggedItem: $draggedItem,
                reduceMotion: reduceMotion
            )
        )
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Gallery Is Empty", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Capture a photo or scan a document. Everything stays on this device until you choose to upload it.")
        } actions: {
            ViewThatFits {
                HStack {
                    emptyStateCaptureButton(title: "Capture", image: "camera.fill", mode: .photo)
                    emptyStateCaptureButton(title: "Scan", image: "doc.viewfinder", mode: .scan)
                }
                VStack {
                    emptyStateCaptureButton(title: "Capture", image: "camera.fill", mode: .photo)
                    emptyStateCaptureButton(title: "Scan", image: "doc.viewfinder", mode: .scan)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyStateCaptureButton(
        title: String,
        image: String,
        mode: CameraCaptureMode
    ) -> some View {
        Button {
            emptyStateCameraMode = mode
        } label: {
            Label(title, systemImage: image)
        }
        .buttonStyle(.borderedProminent)
    }

    func handleItemTap(_ item: GalleryItem) {
        if !isMultiSelectMode {
            guard let image = item.capturedImage else { return }
            guard !isLoadingFullscreen else { return }
            appData.hapticService.playSelection()
            isLoadingFullscreen = true
            let itemID = item.id
            let rotation = item.rotation
            Task {
                let uiImage = await Task.detached(priority: .userInitiated) {
                    autoreleasepool {
                        DocumentImageProcessor.renderedImage(
                            for: image,
                            rotation: rotation,
                            maxPixelDimension: 2400
                        )
                    }
                }.value

                guard !Task.isCancelled else {
                    isLoadingFullscreen = false
                    return
                }
                isLoadingFullscreen = false
                guard let uiImage,
                      galleryItems.contains(where: { $0.id == itemID }) else { return }
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

    func uploadSelectedItemsForCurrentOutputMode() {
        if outputMode == .singlePDF {
            imageName = ""
            isShowingPDFNamingSheet = true
        } else {
            uploadSelectedItems()
        }
    }

    func uploadItems(_ items: [GalleryItem]) {
        guard preparationTask == nil else { return }
        let requests = exportRequests(for: items)
        guard !requests.isEmpty else { return }
        let maxPixelDimension = CGFloat(appData.imageMaxPixelDimension)
        let jpegQuality = CGFloat(appData.pdfJPEGQuality)
        isPreparingUpload = true
        let operationID = preparationOperationGate.begin()

        preparationTask = Task { @MainActor in
            var preparedFiles: [UploadableFile] = []
            defer {
                if preparationOperationGate.finish(operationID) {
                    preparationTask = nil
                    isPreparingUpload = false
                }
            }
            do {
                preparedFiles = try await exportUploads(
                    requests,
                    maxPixelDimension: maxPixelDimension,
                    jpegQuality: jpegQuality
                )
                try Task.checkCancellation()
                guard preparationOperationGate.isCurrent(operationID) else {
                    removeTemporaryFiles(preparedFiles)
                    return
                }
                appData.setPendingUploadFiles(preparedFiles)
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                navigateToUpload = true
            } catch is CancellationError {
                removeTemporaryFiles(preparedFiles)
                return
            } catch {
                removeTemporaryFiles(preparedFiles)
                if preparationOperationGate.isCurrent(operationID) {
                    pdfGenerationError = "Could not prepare cropped pages for upload: \(error.localizedDescription)"
                }
            }
        }
    }

    func leaveEmptySpace(_ item: GalleryItem) {
        guard let capturedImage = item.capturedImage else { return }
        itemToDelete = nil
        Task {
            do {
                try await appData.fileService.removeItem(at: capturedImage.fileURL)
                await MainActor.run {
                    guard let index = galleryItems.firstIndex(where: { $0.id == item.id }) else { return }
                    galleryItems[index].capturedImage = nil
                    galleryItems[index].rotation = .degrees0
                    appData.images.removeAll { $0.id == capturedImage.id }
                }
            } catch {
                await MainActor.run {
                    pdfGenerationError = "Could not delete the local file. The image was kept in Gallery."
                }
            }
        }
    }

    func deleteSpace(_ item: GalleryItem) {
        guard let capturedImage = item.capturedImage else {
            galleryItems.removeAll { $0.id == item.id }
            appData.selectedImageIDs.remove(item.id)
            itemToDelete = nil
            return
        }
        itemToDelete = nil
        Task {
            do {
                try await appData.fileService.removeItem(at: capturedImage.fileURL)
                await MainActor.run {
                    galleryItems.removeAll { $0.id == item.id }
                    appData.images.removeAll { $0.id == capturedImage.id }
                    appData.selectedImageIDs.remove(item.id)
                }
            } catch {
                await MainActor.run {
                    pdfGenerationError = "Could not delete the local file. The image was kept in Gallery."
                }
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

        let emptySpaceIDs = Set(
            galleryItems.compactMap { item in
                selectedIDs.contains(item.id) && item.capturedImage == nil ? item.id : nil
            }
        )

        Task {
            var deletedImageIDs = Set<UUID>()
            var failedDeletions = 0
            for image in imagesToDelete {
                do {
                    try await appData.fileService.removeItem(at: image.fileURL)
                    deletedImageIDs.insert(image.id)
                } catch {
                    failedDeletions += 1
                }
            }
            await MainActor.run {
                let removedGalleryIDs = emptySpaceIDs.union(deletedImageIDs)
                galleryItems.removeAll { removedGalleryIDs.contains($0.id) }
                appData.images.removeAll { deletedImageIDs.contains($0.id) }
                appData.selectedImageIDs.subtract(removedGalleryIDs)
                if failedDeletions == 0 {
                    isMultiSelectMode = false
                    appData.hapticService.playNotification(type: .success)
                } else {
                    pdfGenerationError = "Could not delete \(failedDeletions) local file(s). They remain in Gallery for retry."
                }
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
            let outcome = await appData.saveImagesToDatedFolder(selectedImages)
            await MainActor.run {
                switch outcome {
                case .saved:
                    appData.selectedImageIDs.removeAll()
                    isMultiSelectMode = false
                    appData.hapticService.playNotification(type: .success)
                case .noImages:
                    pdfGenerationError = "No selected images were available to archive."
                    appData.hapticService.playNotification(type: .warning)
                case .failed(let message):
                    pdfGenerationError = "Could not archive the selected images: \(message)"
                    appData.hapticService.playNotification(type: .error)
                }
            }
        }
    }

    @MainActor
    private func rotateAndPersistItems(withIDs ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }

        let validIDs = ids.filter { id in appData.images.contains(where: { $0.id == id }) }
        for id in validIDs {
            appData.rotateImage(withID: id)
        }
        syncItemsFromAppData()
        if !validIDs.isEmpty {
            appData.hapticService.playImpact(style: .light)
        }
    }

    func completeRetake(with image: UIImage) async {
        guard let targetId = retakeTargetId,
              let idx = galleryItems.firstIndex(where: { $0.id == targetId }) else {
            await MainActor.run {
                retakeImage = nil
                retakeTargetId = nil
                retakeReviewData = nil
            }
            return
        }

        do {
            let captured = try await appData.saveCapturedUIImage(image, suggestedPrefix: "RETAKE")
            let previousImage = galleryItems[idx].capturedImage
            if let previousImage {
                do {
                    try await appData.fileService.removeItem(at: previousImage.fileURL)
                } catch {
                    // Keep the old queue entry authoritative when its file cannot be
                    // removed. Best-effort cleanup prevents an untracked retake file.
                    try? await appData.fileService.removeItem(at: captured.fileURL)
                    throw error
                }
            }
            await MainActor.run {
                galleryItems[idx] = GalleryItem(id: captured.id, capturedImage: captured, rotation: .degrees0)
                if let previousImage {
                    appData.replaceImage(withID: previousImage.id, with: captured)
                } else {
                    appData.images.append(captured)
                }
                retakeImage = nil
                retakeTargetId = nil
                retakeReviewData = nil
            }
        } catch {
            await MainActor.run {
                retakeImage = nil
                retakeTargetId = nil
                retakeReviewData = nil
                retakeError = "Could not replace the original image: \(error.localizedDescription)"
            }
        }
    }

    private func clearRetakeState() {
        retakeImage = nil
        retakeTargetId = nil
        retakeReviewData = nil
    }

    @MainActor
    private func exportRequests(for items: [GalleryItem]) -> [GalleryExportRequest] {
        items.enumerated().compactMap { order, item in
            guard let itemImage = item.capturedImage,
                  let image = appData.images.first(where: { $0.id == itemImage.id })
            else { return nil }
            return GalleryExportRequest(order: order, image: image, name: image.name)
        }
    }

    @MainActor
    private func renameSelectedImages(baseName: String) -> [GalleryExportRequest] {
        let selectedIDs = appData.selectedImageIDs
        let orderedItems = galleryItems.filter { item in
            selectedIDs.contains(item.id) && item.capturedImage != nil
        }

        var requests: [GalleryExportRequest] = []
        for (index, item) in orderedItems.enumerated() {
            guard let image = item.capturedImage,
                  let appIndex = appData.images.firstIndex(where: { $0.id == image.id })
            else { continue }

            let formattedIndex = String(format: "%02d", index + 1)
            let renamedImage = "\(baseName)\(formattedIndex)"
            updateImageName(renamedImage, at: appIndex)
            requests.append(
                GalleryExportRequest(order: index, image: appData.images[appIndex], name: renamedImage)
            )
        }
        syncItemsFromAppData()
        return requests
    }

    private func exportUploads(
        _ requests: [GalleryExportRequest],
        maxPixelDimension: CGFloat,
        jpegQuality: CGFloat
    ) async throws -> [UploadableFile] {
        var files: [(Int, UploadableFile)] = []
        files.reserveCapacity(requests.count)
        do {
            for request in requests {
                try Task.checkCancellation()
                let file = try await Task.detached(priority: .userInitiated) {
                    try autoreleasepool {
                        let exportURL = try DocumentImageProcessor.exportJPEG(
                            for: request.image,
                            rotation: request.image.rotation,
                            name: request.name,
                            maxPixelDimension: maxPixelDimension,
                            jpegQuality: jpegQuality
                        )
                        return UploadableFile(
                            id: request.image.id,
                            name: request.name,
                            fileURL: exportURL,
                            kind: .jpeg,
                            sourceImageIDs: [request.image.id]
                        )
                    }
                }.value
                files.append((request.order, file))
            }
        } catch {
            for (_, file) in files {
                try? FileManager.default.removeItem(at: file.fileURL)
            }
            throw error
        }
        return files.sorted { $0.0 < $1.0 }.map(\.1)
    }

    @MainActor
    private func updateImageName(_ name: String, at index: Int) {
        appData.images[index].name = name
    }

    func batchRenameImages() {
        guard !imageName.isEmpty else { return }
        _ = renameSelectedImages(baseName: imageName)
        appData.selectedImageIDs.removeAll()
        isMultiSelectMode = false
        imageName = ""
        appData.hapticService.playNotification(type: .success)
    }

    func batchRenameAndUpload() {
        guard !imageName.isEmpty else { return }
        guard preparationTask == nil else { return }
        let requests = renameSelectedImages(baseName: imageName)
        let maxPixelDimension = CGFloat(appData.imageMaxPixelDimension)
        let jpegQuality = CGFloat(appData.pdfJPEGQuality)
        isShowingNamingSheet = false
        isPreparingUpload = true
        let operationID = preparationOperationGate.begin()

        preparationTask = Task { @MainActor in
            var preparedFiles: [UploadableFile] = []
            defer {
                if preparationOperationGate.finish(operationID) {
                    preparationTask = nil
                    isPreparingUpload = false
                }
            }
            do {
                preparedFiles = try await exportUploads(
                    requests,
                    maxPixelDimension: maxPixelDimension,
                    jpegQuality: jpegQuality
                )
                try Task.checkCancellation()
                guard preparationOperationGate.isCurrent(operationID) else {
                    removeTemporaryFiles(preparedFiles)
                    return
                }
                appData.setPendingUploadFiles(preparedFiles)
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                imageName = ""
                navigateToUpload = true
            } catch is CancellationError {
                removeTemporaryFiles(preparedFiles)
                return
            } catch {
                removeTemporaryFiles(preparedFiles)
                if preparationOperationGate.isCurrent(operationID) {
                    pdfGenerationError = "Could not prepare cropped pages for upload: \(error.localizedDescription)"
                }
            }
        }
    }

    func renameImage() {
        guard let image = selectedImage,
            let index = appData.images.firstIndex(where: { $0.id == image.id })
        else { return }
        updateImageName(imageName.isEmpty ? "Image" : imageName, at: index)
        syncItemsFromAppData()
        selectedImage = nil
        imageName = ""
        isShowingNamingSheet = false
    }

    func generateAndUploadPDF() {
        guard !imageName.isEmpty else { return }
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        let operationID = pdfOperationGate.begin()
        isShowingPDFNamingSheet = false

        let settings = PDFSettings(
            pageSize: appData.pdfPageSize,
            imageLayout: appData.pdfImageLayout,
            includePageNumbers: appData.pdfIncludePageNumbers,
            jpegQuality: appData.pdfCompressionLevel.jpegQuality,
            margin: 24,
            maxPixelDimension: appData.pdfCompressionLevel.maxPixelDimension
        )

        let selectedIDs = appData.selectedImageIDs
        let itemsToProcess = selectedIDs.isEmpty
            ? galleryItems
            : galleryItems.filter { selectedIDs.contains($0.id) }
        let finalName = imageName
        let sourceImageIDs = Set(itemsToProcess.compactMap { $0.capturedImage?.id })

        let generationTask = Task.detached(priority: .userInitiated) {
            try await PDFGenerationService.shared.generatePDF(
                from: itemsToProcess,
                outputName: finalName,
                settings: settings
            )
        }

        pdfGenerationTask = Task { @MainActor in
            var generatedPDFURL: URL?
            var handedOffToUpload = false
            defer {
                if !handedOffToUpload, let generatedPDFURL {
                    try? FileManager.default.removeItem(at: generatedPDFURL)
                }
                if pdfOperationGate.finish(operationID) {
                    pdfGenerationTask = nil
                    isGeneratingPDF = false
                }
            }
            do {
                let pdfURL = try await withTaskCancellationHandler(operation: {
                    try await generationTask.value
                }, onCancel: {
                    generationTask.cancel()
                })
                generatedPDFURL = pdfURL
                try Task.checkCancellation()
                guard pdfOperationGate.isCurrent(operationID) else { return }

                let uploadFile = UploadableFile(
                    id: UUID(),
                    name: finalName,
                    fileURL: pdfURL,
                    kind: .pdf,
                    sourceImageIDs: sourceImageIDs
                )

                appData.setPendingUploadFiles([uploadFile])
                appData.selectedImageIDs.removeAll()
                isMultiSelectMode = false
                imageName = ""
                navigateToUpload = true
                handedOffToUpload = true
            } catch {
                if pdfOperationGate.isCurrent(operationID) {
                    pdfGenerationError = error.localizedDescription
                }
            }
        }
    }

    private func cancelPDFGeneration() {
        let task = pdfGenerationTask
        pdfOperationGate.cancel()
        task?.cancel()
        pdfGenerationTask = nil
        isGeneratingPDF = false
        imageName = ""
    }

    private func cancelProcessing() {
        if isGeneratingPDF {
            cancelPDFGeneration()
        } else {
            let task = preparationTask
            preparationOperationGate.cancel()
            task?.cancel()
            preparationTask = nil
            isPreparingUpload = false
        }
    }

    private func removeTemporaryFiles(_ files: [UploadableFile]) {
        for file in files {
            try? FileManager.default.removeItem(at: file.fileURL)
        }
    }

    private func syncItemsFromAppData() {
        let appDataImagesByID = Dictionary(uniqueKeysWithValues: appData.images.map { ($0.id, $0) })
        var updatedItems = galleryItems.compactMap { item -> GalleryItem? in
            if let image = item.capturedImage {
                guard let updatedImage = appDataImagesByID[image.id] else { return nil }
                return GalleryItem(id: item.id, capturedImage: updatedImage, rotation: updatedImage.rotation)
            }
            return item
        }

        let existingImageIDs = Set(updatedItems.compactMap { $0.capturedImage?.id })
        for image in appData.images where !existingImageIDs.contains(image.id) {
            updatedItems.append(GalleryItem(id: image.id, capturedImage: image, rotation: image.rotation))
        }

        galleryItems = updatedItems
    }
}

struct ReorderDropDelegate: DropDelegate {
    let item: GalleryItem
    @Binding var items: [GalleryItem]
    @Binding var draggedItem: GalleryItem?
    let reduceMotion: Bool

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem else { return }
        guard dragged.id != item.id else { return }

        if let fromIndex = items.firstIndex(of: dragged),
           let toIndex = items.firstIndex(of: item) {
            withAnimation(reduceMotion ? nil : .default) {
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

struct CropEditorView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onSave: (DocumentCrop) -> Void

    @State private var crop: DocumentCrop
    @State private var dragOrigin: DocumentCrop?
    @State private var activePoint: CGPoint?

    init(
        sourceImage: UIImage,
        initialCrop: DocumentCrop,
        onCancel: @escaping () -> Void,
        onSave: @escaping (DocumentCrop) -> Void
    ) {
        self.sourceImage = sourceImage
        self.onCancel = onCancel
        self.onSave = onSave
        _crop = State(initialValue: initialCrop.clamped())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                GeometryReader { geometry in
                    let frame = aspectFitFrame(in: geometry.size)
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    CropPolygon(crop: crop, imageFrame: frame)

                    ForEach(CropControl.allCases) { control in
                        let position = position(for: control, in: frame)
                        Circle()
                            .fill(control.isCorner ? .white : .yellow)
                            .frame(width: control.isCorner ? 26 : 30, height: control.isCorner ? 26 : 16)
                            .position(position)
                            .gesture(dragGesture(for: control, in: frame))
                            .accessibilityLabel(control.accessibilityLabel)
                            .accessibilityHint("Use the move actions to adjust the document crop")
                            .accessibilityAction(named: "Move left") {
                                adjust(control, x: -0.02, y: 0)
                            }
                            .accessibilityAction(named: "Move right") {
                                adjust(control, x: 0.02, y: 0)
                            }
                            .accessibilityAction(named: "Move up") {
                                adjust(control, x: 0, y: -0.02)
                            }
                            .accessibilityAction(named: "Move down") {
                                adjust(control, x: 0, y: 0.02)
                            }
                    }

                    if let activePoint {
                        CropMagnifier(
                            image: sourceImage,
                            focus: activePoint,
                            frame: frame
                        )
                    }
                }
                .padding(.vertical, 18)
            }
            .navigationTitle("Edit Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(crop.clamped()) }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func aspectFitFrame(in available: CGSize) -> CGRect {
        let horizontalPadding: CGFloat = 16
        let width = available.width - horizontalPadding * 2
        let height = max(available.height - 80, 1)
        let scale = min(width / sourceImage.size.width, height / sourceImage.size.height)
        let size = CGSize(width: sourceImage.size.width * scale, height: sourceImage.size.height * scale)
        return CGRect(
            x: (available.width - size.width) / 2,
            y: (available.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func position(for control: CropControl, in frame: CGRect) -> CGPoint {
        let point = control.point(in: crop)
        return CGPoint(x: frame.minX + point.x * frame.width, y: frame.minY + point.y * frame.height)
    }

    private func dragGesture(for control: CropControl, in frame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragOrigin == nil { dragOrigin = crop }
                guard let startCrop = dragOrigin else { return }
                let delta = CGPoint(
                    x: value.translation.width / frame.width,
                    y: value.translation.height / frame.height
                )
                crop = control.moving(in: startCrop, delta: delta).clamped()
                activePoint = control.point(in: crop)
            }
            .onEnded { _ in
                dragOrigin = nil
                activePoint = nil
            }
    }

    private func adjust(_ control: CropControl, x: CGFloat, y: CGFloat) {
        crop = control.moving(in: crop, delta: CGPoint(x: x, y: y)).clamped()
    }
}

private struct CropPolygon: View {
    let crop: DocumentCrop
    let imageFrame: CGRect

    var body: some View {
        Path { path in
            let points = crop.points.map {
                CGPoint(x: imageFrame.minX + $0.x * imageFrame.width, y: imageFrame.minY + $0.y * imageFrame.height)
            }
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
        .stroke(.yellow, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }
}

private struct CropMagnifier: View {
    let image: UIImage
    let focus: CGPoint
    let frame: CGRect

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 110, height: 110)
            .scaleEffect(2.5, anchor: UnitPoint(x: focus.x, y: focus.y))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .overlay {
                Circle().stroke(.yellow.opacity(0.9), lineWidth: 1).frame(width: 22, height: 22)
            }
            .position(
                x: min(max(frame.minX + focus.x * frame.width, 70), frame.maxX - 70),
                y: max(frame.minY + focus.y * frame.height - 90, frame.minY + 60)
            )
            .allowsHitTesting(false)
    }
}

private enum CropControl: String, CaseIterable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var id: String { rawValue }
    var isCorner: Bool { [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(self) }
    var accessibilityLabel: String {
        switch self {
        case .topLeft: "Top left crop handle"
        case .top: "Top crop handle"
        case .topRight: "Top right crop handle"
        case .right: "Right crop handle"
        case .bottomRight: "Bottom right crop handle"
        case .bottom: "Bottom crop handle"
        case .bottomLeft: "Bottom left crop handle"
        case .left: "Left crop handle"
        }
    }

    func point(in crop: DocumentCrop) -> CGPoint {
        switch self {
        case .topLeft: return crop.topLeft
        case .top: return midpoint(crop.topLeft, crop.topRight)
        case .topRight: return crop.topRight
        case .right: return midpoint(crop.topRight, crop.bottomRight)
        case .bottomRight: return crop.bottomRight
        case .bottom: return midpoint(crop.bottomLeft, crop.bottomRight)
        case .bottomLeft: return crop.bottomLeft
        case .left: return midpoint(crop.topLeft, crop.bottomLeft)
        }
    }

    func moving(in crop: DocumentCrop, delta: CGPoint) -> DocumentCrop {
        var updated = crop
        switch self {
        case .topLeft: updated.topLeft = offset(crop.topLeft, delta)
        case .topRight: updated.topRight = offset(crop.topRight, delta)
        case .bottomRight: updated.bottomRight = offset(crop.bottomRight, delta)
        case .bottomLeft: updated.bottomLeft = offset(crop.bottomLeft, delta)
        case .top:
            updated.topLeft = offset(crop.topLeft, delta)
            updated.topRight = offset(crop.topRight, delta)
        case .right:
            updated.topRight = offset(crop.topRight, delta)
            updated.bottomRight = offset(crop.bottomRight, delta)
        case .bottom:
            updated.bottomLeft = offset(crop.bottomLeft, delta)
            updated.bottomRight = offset(crop.bottomRight, delta)
        case .left:
            updated.topLeft = offset(crop.topLeft, delta)
            updated.bottomLeft = offset(crop.bottomLeft, delta)
        }
        return updated
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func offset(_ point: CGPoint, _ delta: CGPoint) -> CGPoint {
        CGPoint(x: point.x + delta.x, y: point.y + delta.y)
    }
}
