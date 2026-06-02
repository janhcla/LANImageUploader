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

private struct GalleryExportRequest {
    let order: Int
    let image: CapturedImage
    let name: String
}

struct GalleryView: View {
    let initialOutputMode: GalleryOutputMode?
    @EnvironmentObject var appData: AppData
    @State private var isMultiSelectMode = false
    @State private var isShowingNamingSheet = false
    @State private var imageName = ""
    @State private var namingIntent: GalleryNamingIntent = .singleRename
    @State private var selectedImage: CapturedImage?
    @State private var navigateToUpload = false
    @State private var fullscreenData: FullscreenImageData?
    @State private var cropEditingItem: GalleryItem?

    // Deletion states
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: GalleryItem?

    // Mode
    @State private var outputMode: GalleryOutputMode

    // PDF Naming
    @State private var isShowingPDFNamingSheet = false
    @State private var isGeneratingPDF = false
    @State private var pdfGenerationError: String? = nil

    // Retake logic
    @State private var retakeTargetId: UUID? = nil
    @State private var isShowingRetakeCamera = false
    @State private var retakeImage: UIImage? = nil
    @State private var retakeReviewData: RetakeReviewData?

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
            .sheet(item: $retakeReviewData) { data in
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
            .navigationDestination(isPresented: $navigateToUpload) {
                UploadView(fallbackToGalleryImages: false).environmentObject(appData)
            }
            .safeAreaInset(edge: .bottom) {
                if isMultiSelectMode && !appData.selectedImageIDs.isEmpty {
                    MultiSelectToolbarView(
                        appData: appData,
                        onUpload: uploadSelectedItemsForCurrentOutputMode,
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
            if let uiImage = DocumentImageProcessor.renderedImage(for: image, rotation: item.rotation) {
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
        let requests = exportRequests(for: items)
        guard !requests.isEmpty else { return }
        let maxPixelDimension = CGFloat(appData.imageMaxPixelDimension)
        let jpegQuality = CGFloat(appData.pdfJPEGQuality)

        Task {
            do {
                let files = try await exportUploads(
                    requests,
                    maxPixelDimension: maxPixelDimension,
                    jpegQuality: jpegQuality
                )
                await MainActor.run {
                    appData.pendingUploadFiles = files
                    appData.selectedImageIDs.removeAll()
                    isMultiSelectMode = false
                    navigateToUpload = true
                }
            } catch {
                await MainActor.run {
                    pdfGenerationError = "Could not prepare cropped pages for upload: \(error.localizedDescription)"
                }
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
            await MainActor.run {
                deleteLocalImage(galleryItems[idx].capturedImage)
                galleryItems[idx] = GalleryItem(id: captured.id, capturedImage: captured, rotation: .degrees0)
                appData.images.append(captured)
                retakeImage = nil
                retakeTargetId = nil
                retakeReviewData = nil
            }
        } catch {
            await MainActor.run {
                retakeImage = nil
                retakeTargetId = nil
                retakeReviewData = nil
            }
        }
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
        try await withThrowingTaskGroup(of: (Int, UploadableFile).self) { group in
            for request in requests {
                group.addTask {
                    let file = try autoreleasepool {
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
                    return (request.order, file)
                }
            }

            var files: [(Int, UploadableFile)] = []
            for try await file in group {
                files.append(file)
            }
            return files.sorted { $0.0 < $1.0 }.map(\.1)
        }
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
        let requests = renameSelectedImages(baseName: imageName)
        let maxPixelDimension = CGFloat(appData.imageMaxPixelDimension)
        let jpegQuality = CGFloat(appData.pdfJPEGQuality)

        Task {
            do {
                let files = try await exportUploads(
                    requests,
                    maxPixelDimension: maxPixelDimension,
                    jpegQuality: jpegQuality
                )
                await MainActor.run {
                    appData.pendingUploadFiles = files
                    appData.selectedImageIDs.removeAll()
                    isMultiSelectMode = false
                    imageName = ""
                    navigateToUpload = true
                }
            } catch {
                await MainActor.run {
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
        isGeneratingPDF = true

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
                    kind: .pdf,
                    sourceImageIDs: Set(itemsToProcess.compactMap { $0.capturedImage?.id })
                )

                await MainActor.run {
                    appData.pendingUploadFiles = [uploadFile]
                    appData.selectedImageIDs.removeAll()
                    isMultiSelectMode = false
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
                            .accessibilityHint("Drag to adjust document crop")
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
    var accessibilityLabel: String { "\(rawValue) crop handle" }

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
