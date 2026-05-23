//
//  GalleryView.swift
//  LANImageUploader
//

import SwiftUI
import UIKit

struct GalleryView: View {
    @EnvironmentObject var appData: AppData
    @State private var isMultiSelectMode = false
    @State private var isShowingNamingSheet = false
    @State private var imageName = ""
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
                                GalleryItemView(
                                    index: index,
                                    item: item,
                                    isSelected: isMultiSelectMode && appData.selectedImageIDs.contains(item.id),
                                    isMultiSelectMode: isMultiSelectMode,
                                    onTap: { handleItemTap(item) },
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
                                .onDrag {
                                    self.draggedItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: ReorderDropDelegate(item: item, items: $galleryItems, draggedItem: $draggedItem))
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
                        if isMultiSelectMode {
                            batchRenameAndUpload()
                        } else {
                            renameImage()
                        }
                    },
                    saveButtonLabel: isMultiSelectMode ? "Save & Upload" : "Save"
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
                if !galleryItems.isEmpty && !isMultiSelectMode {
                    GlassContainer(cornerRadius: 20) {
                        VStack(spacing: 12) {
                            Picker("Output Mode", selection: $outputMode) {
                                ForEach(GalleryOutputMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 16) {
                                Button(action: {
                                    if outputMode == .separateImages {
                                        appData.selectedImageIDs = Set(galleryItems.compactMap { $0.capturedImage?.id })
                                        isShowingNamingSheet = true
                                    } else {
                                        isShowingPDFNamingSheet = true
                                    }
                                }) {
                                    Label(outputMode == .separateImages ? "Batch Upload" : "Create PDF & Upload",
                                          systemImage: outputMode == .separateImages ? "square.and.pencil" : "doc.text")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                }
                                .buttonStyle(OrangeButtonStyle())
                                .disabled(isGeneratingPDF)
                            }
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
        .onChange(of: appData.images) { _, _ in
            syncItemsFromAppData()
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
        guard let idx = galleryItems.firstIndex(where: { $0.id == item.id }) else { return }
        galleryItems[idx].rotation = galleryItems[idx].rotation.nextClockwise
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
                galleryItems[idx].capturedImage = captured
                galleryItems[idx].rotation = .degrees0
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

    func batchRenameAndUpload() {
        guard !imageName.isEmpty else { return }

        let orderedItems = galleryItems.filter { appData.selectedImageIDs.contains($0.id) && $0.capturedImage != nil }
        for (index, item) in orderedItems.enumerated() {
            if let img = item.capturedImage, let appIdx = appData.images.firstIndex(where: { $0.id == img.id }) {
                let formattedIndex = String(format: "%02d", index + 1)
                appData.images[appIdx].name = "\(imageName)\(formattedIndex)"
            }
        }

        appData.pendingUploadFiles = nil
        Task {
            await applyRotationsBeforeUpload()
            await MainActor.run {
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

            if let uiImage = UIImage(contentsOfFile: img.fileURL.path) {
                let rotated = uiImage.rotatedClockwise(by: item.rotation)
                if let data = rotated.jpegData(compressionQuality: 0.8) {
                    try? await appData.fileService.removeItem(at: img.fileURL)
                    if let newURL = try? await appData.fileService.saveImage(data, fileName: img.fileURL.lastPathComponent) {
                        await MainActor.run {
                            appData.images[idx].fileURL = newURL
                            if let galleryIdx = galleryItems.firstIndex(where: { $0.id == item.id }) {
                                galleryItems[galleryIdx].rotation = .degrees0
                            }
                        }
                    }
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

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
