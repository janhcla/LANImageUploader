//
//  ArchiveView.swift
//  LANImageUploader
//

import OSLog
import SwiftUI
import UIKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "LANImageUploader",
    category: "ArchiveView"
)

// Custom struct to make URL Identifiable
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ArchiveView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isRenameFieldFocused: Bool
    @State private var selectedDate: String?
    @State private var showDeleteAllConfirmation = false
    @State private var showRenameSheet = false
    @State private var selectedDates: Set<String> = []
    @State private var isMultiSelectMode = false
    @State private var dateToRename: String = ""
    @State private var newArchiveName: String = ""
    @State private var customArchiveNames: [String: String] = [:]
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage = ""
    @State private var showDeleteSelectedConfirmation = false
    @State private var archivedDates: [String] = []
    @State private var isPerformingArchiveAction = false

    private var hasArchives: Bool {
        !archivedDates.isEmpty
    }

    var body: some View {
        BackgroundContainerView {
                List {
                    if archivedDates.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No archives yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Archived gallery images will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(archivedDates, id: \.self) { date in
                            archiveRow(for: date)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Archives")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if hasArchives {
                            Button(isMultiSelectMode ? "Done" : "Select") {
                                appData.hapticService.playSelection()
                                withAnimation(reduceMotion ? nil : .spring()) {
                                    isMultiSelectMode.toggle()
                                    if !isMultiSelectMode {
                                        selectedDates.removeAll()
                                    }
                                }
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if hasArchives {
                        GlassContainer(cornerRadius: 20) {
                            if isMultiSelectMode && !selectedDates.isEmpty {
                                HStack(spacing: 16) {
                                    Button(action: { Task { await restoreSelectedArchives() } }) {
                                        archiveActionLabel("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .green))
                                    .disabled(isPerformingArchiveAction)

                                    Button(action: {
                                        showDeleteSelectedConfirmation = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
                                    .disabled(isPerformingArchiveAction)
                                }
                            } else if !isMultiSelectMode {
                                Button(action: {
                                    showDeleteAllConfirmation = true
                                }) {
                                    Label("Delete All Archives", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
                                .disabled(isPerformingArchiveAction)
                            }
                        }
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .alert("Delete All Archives?", isPresented: $showDeleteAllConfirmation) {
                    Button("Delete All", role: .destructive) { Task { await deleteAllArchives() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes every archived image. Images currently in Gallery are not affected.")
                }
                .alert("Delete Selected", isPresented: $showDeleteSelectedConfirmation) {
                    Button("Delete", role: .destructive) { Task { await deleteSelectedArchives() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Permanently delete \(selectedDates.count) selected \(selectedDates.count == 1 ? "archive" : "archives")?")
                }
                .alert("Restore Result", isPresented: $showRestoreConfirmation) {
                    Button("OK") { showRestoreConfirmation = false }
                } message: {
                    Text(restoreMessage)
                }
                .sheet(isPresented: $showRenameSheet) {
                    renameArchiveSheet
                }
            .sheet(
                isPresented: Binding(
                    get: { selectedDate != nil },
                    set: { selectedDate = $0 ? selectedDate : nil }
                )
            ) {
                if let date = selectedDate {
                    ArchivedImagesView(date: date, displayName: customArchiveNames[date] ?? date)
                }
            }
            .onAppear {
                loadCustomArchiveNames()
                Task { await refreshArchivedDates() }
            }
        }
    }

    private func refreshArchivedDates() async {
        let dates = await appData.getArchivedDates()
        await MainActor.run {
            self.archivedDates = dates
        }
    }

    @ViewBuilder
    var renameArchiveSheet: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                Text("Rename Archive")
                    .font(.headline)
                    .padding(.top)
                
                GlassContainer(cornerRadius: 16) {
                    TextField("Archive Name", text: $newArchiveName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isRenameFieldFocused)
                        .onSubmit(saveArchiveNameIfValid)
                }
                
                HStack(spacing: 16) {
                    Button("Cancel") { showRenameSheet = false }
                        .buttonStyle(GrayButtonStyle())
                    
                    Button("Save") {
                        saveArchiveNameIfValid()
                    }
                    .buttonStyle(BlueButtonStyle())
                    .disabled(!isArchiveNameValid)
                }
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .onAppear { isRenameFieldFocused = true }
    }

    @ViewBuilder
    func archiveRow(for date: String) -> some View {
        let isSelected = selectedDates.contains(date)
        let displayName = customArchiveNames[date] ?? date

        GlassContainer(cornerRadius: 16) {
            HStack {
                if isMultiSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .padding(.trailing, 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if displayName != date {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()

                if !isMultiSelectMode {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isMultiSelectMode {
                    appData.hapticService.playImpact(style: .light)
                    if isSelected {
                        selectedDates.remove(date)
                    } else {
                        selectedDates.insert(date)
                    }
                } else {
                    appData.hapticService.playSelection()
                    selectedDate = date
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                selectedDates = [date]
                showDeleteSelectedConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                dateToRename = date
                newArchiveName = displayName
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func saveRenamedArchive() {
        guard !dateToRename.isEmpty, isArchiveNameValid else { return }
        customArchiveNames[dateToRename] = trimmedArchiveName
        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: Constants.UserDefaults.archiveCustomNames)
        }
        appData.hapticService.playNotification(type: .success)
        dateToRename = ""
    }

    private var trimmedArchiveName: String {
        newArchiveName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isArchiveNameValid: Bool {
        !trimmedArchiveName.isEmpty && trimmedArchiveName.rangeOfCharacter(from: CharacterSet(charactersIn: "/:\\")) == nil
    }

    private func saveArchiveNameIfValid() {
        guard isArchiveNameValid else { return }
        saveRenamedArchive()
        showRenameSheet = false
    }

    @ViewBuilder
    private func archiveActionLabel(_ title: String, systemImage: String) -> some View {
        if isPerformingArchiveAction {
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Working")
        } else {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }

    private func loadCustomArchiveNames() {
        if let savedData = UserDefaults.standard.data(forKey: Constants.UserDefaults.archiveCustomNames),
            let decoded = try? JSONDecoder().decode([String: String].self, from: savedData)
        {
            customArchiveNames = decoded
        }
    }

    private func restoreSelectedArchives() async {
        guard !isPerformingArchiveAction else { return }
        isPerformingArchiveAction = true
        defer { isPerformingArchiveAction = false }
        appData.hapticService.playLiquidBounce()
        let datesToRestore = Array(selectedDates)
        let docs = await appData.fileService.documentsDirectory
        let imagesFolderURL = docs.appendingPathComponent("images")

        try? await appData.fileService.createDirectory(at: imagesFolderURL)

        let existingImageURLs = await MainActor.run {
            Set(appData.images.map(\.fileURL))
        }

        var seenDestinationURLs = existingImageURLs
        var imagesToRestore: [(source: URL, destination: URL)] = []
        var skippedCount = 0

        var fetchedImages: [URL] = []
        for date in datesToRestore {
            guard !Task.isCancelled else { return }
            fetchedImages.append(contentsOf: await appData.getImagesForDate(date))
        }

        for imageURL in fetchedImages {
            let destinationURL = imagesFolderURL.appendingPathComponent(imageURL.lastPathComponent)
            if seenDestinationURLs.insert(destinationURL).inserted {
                imagesToRestore.append((source: imageURL, destination: destinationURL))
            } else {
                skippedCount += 1
            }
        }

        var restoredCount = 0
        var failedCount = 0
        var allRestored: [CapturedImage] = []
        for image in imagesToRestore {
            guard !Task.isCancelled else { return }
            do {
                if await appData.fileService.fileExists(at: image.destination) {
                    try await appData.fileService.removeItem(at: image.destination)
                }
                try await appData.fileService.copyItem(at: image.source, to: image.destination)
                allRestored.append(CapturedImage(
                    name: image.source.deletingPathExtension().lastPathComponent,
                    fileURL: image.destination
                ))
                restoredCount += 1
            } catch {
                logger.error("Failed to restore archived image: \(error, privacy: .private)")
                failedCount += 1
            }
        }

        await MainActor.run {
            appData.images.append(contentsOf: allRestored)
            var resultParts = ["Restored \(restoredCount) \(restoredCount == 1 ? "image" : "images")"]
            if skippedCount > 0 {
                resultParts.append("\(skippedCount) already in Gallery")
            }
            if failedCount > 0 {
                resultParts.append("\(failedCount) could not be restored")
            }
            restoreMessage = resultParts.joined(separator: ". ") + "."
            showRestoreConfirmation = true
            selectedDates.removeAll()
            isMultiSelectMode = false
            appData.hapticService.playNotification(type: failedCount > 0 ? .warning : .success)
        }
    }

    private func deleteSelectedArchives() async {
        guard !isPerformingArchiveAction else { return }
        isPerformingArchiveAction = true
        defer { isPerformingArchiveAction = false }
        let docs = await appData.fileService.documentsDirectory
        let datesToDelete = Array(selectedDates)

        var deletedResults: [String] = []
        for date in datesToDelete {
            guard !Task.isCancelled else { return }
            let archiveURL = docs.appendingPathComponent(date)
            do {
                try await appData.fileService.removeItem(at: archiveURL)
                deletedResults.append(date)
            } catch {
                logger.error("Failed to delete archive: \(error, privacy: .private)")
            }
        }

        for date in deletedResults {
            customArchiveNames.removeValue(forKey: date)
        }

        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: Constants.UserDefaults.archiveCustomNames)
        }

        await refreshArchivedDates()
        await MainActor.run {
            selectedDates.removeAll()
            isMultiSelectMode = false
            appData.hapticService.playNotification(type: .success)
        }
    }

    private func deleteAllArchives() async {
        guard !isPerformingArchiveAction else { return }
        isPerformingArchiveAction = true
        defer { isPerformingArchiveAction = false }
        let archives = await appData.getArchivedDates()
        let docs = await appData.fileService.documentsDirectory

        var deletedResults: [String] = []
        for archive in archives {
            guard !Task.isCancelled else { return }
            let archiveURL = docs.appendingPathComponent(archive)
            do {
                try await appData.fileService.removeItem(at: archiveURL)
                deletedResults.append(archive)
            } catch {
                logger.error("Failed to delete archive: \(error, privacy: .private)")
            }
        }

        for archive in deletedResults {
            customArchiveNames.removeValue(forKey: archive)
        }

        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: Constants.UserDefaults.archiveCustomNames)
        }
        
        await refreshArchivedDates()
        await MainActor.run {
            appData.hapticService.playNotification(type: .success)
        }
    }
}

struct ArchivedImagesView: View {
    let date: String
    var displayName: String
    @EnvironmentObject var appData: AppData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedImages: Set<URL> = []
    @State private var isMultiSelectMode = false
    @State private var selectedImageURL: IdentifiableURL? = nil
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage = ""
    @State private var showDeleteSelectedConfirmation = false
    @State private var images: [URL] = []
    @State private var isPerformingAction = false

    var body: some View {
        BackgroundContainerView {
            NavigationStack {
                ZStack {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                            ForEach(images, id: \.self) { imageURL in
                                imageThumbnail(for: imageURL)
                            }
                        }
                        .padding()
                    }
                    .background(Color.clear)
                    .navigationTitle(displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { dismiss() }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(isMultiSelectMode ? "Done" : "Select") {
                                appData.hapticService.playSelection()
                                withAnimation(reduceMotion ? nil : .spring()) {
                                    isMultiSelectMode.toggle()
                                    if !isMultiSelectMode { selectedImages.removeAll() }
                                }
                            }
                        }
                    }
                    
                    if isMultiSelectMode && !selectedImages.isEmpty {
                        VStack {
                            Spacer()
                            GlassContainer(cornerRadius: 20) {
                                HStack(spacing: 16) {
                                    Button(action: { Task { await restoreSelectedImages() } }) {
                                        archivedImageActionLabel("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .green))
                                    .disabled(isPerformingAction)

                                    Button(action: {
                                        showDeleteSelectedConfirmation = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
                                    .disabled(isPerformingAction)
                                }
                            }
                            .padding()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !isMultiSelectMode && !images.isEmpty {
                        Button(action: { Task { await restoreAllImages() } }) {
                            archivedImageActionLabel("Restore All Images", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(LiquidButtonStyle(backgroundColor: .green))
                        .disabled(isPerformingAction)
                        .padding()
                    }
                }
                .alert("Restore", isPresented: $showRestoreConfirmation) {
                    Button("OK") { showRestoreConfirmation = false }
                } message: {
                    Text(restoreMessage)
                }
                .alert("Delete", isPresented: $showDeleteSelectedConfirmation) {
                    Button("Delete", role: .destructive) { Task { await deleteSelectedImages() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete the selected images from the archive?")
                }
                .fullScreenCover(item: $selectedImageURL) { identifiableURL in
                    ArchivedImageViewer(
                        imageURL: identifiableURL.url,
                        onDelete: {
                            selectedImages = [identifiableURL.url]
                            selectedImageURL = nil
                            DispatchQueue.main.async {
                                showDeleteSelectedConfirmation = true
                            }
                        },
                        onSave: {
                            Task { await restoreSingleImage(identifiableURL.url) }
                        }
                    )
                }
                .onAppear {
                    Task { await refreshImages() }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    func imageThumbnail(for imageURL: URL) -> some View {
        ArchiveThumbnailView(
            imageURL: imageURL,
            isSelected: selectedImages.contains(imageURL),
            isMultiSelectMode: isMultiSelectMode,
            onTap: {
                if !isMultiSelectMode {
                    appData.hapticService.playSelection()
                    selectedImageURL = IdentifiableURL(url: imageURL)
                } else {
                    appData.hapticService.playImpact(style: .light)
                    if selectedImages.contains(imageURL) {
                        selectedImages.remove(imageURL)
                    } else {
                        selectedImages.insert(imageURL)
                    }
                }
            }
        )
    }

    func restoreAllImages() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        let images = await appData.getImagesForDate(date)
        await restoreImages(images)
    }

    func restoreSelectedImages() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        await restoreImages(Array(selectedImages))
        await MainActor.run {
            selectedImages.removeAll()
            isMultiSelectMode = false
        }
    }

    private func restoreSingleImage(_ imageURL: URL) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        await restoreImages([imageURL])
    }

    private func restoreImages(_ imageURLs: [URL]) async {
        let docs = await appData.fileService.documentsDirectory
        let imagesFolderURL = docs.appendingPathComponent("images")

        do {
            try await appData.fileService.createDirectory(at: imagesFolderURL)

            let existingImageURLs = await MainActor.run {
                Set(appData.images.map(\.fileURL))
            }

            var seenDestinationURLs = existingImageURLs
            let imagesToRestore = imageURLs.compactMap { imageURL -> (source: URL, destination: URL)? in
                let destinationURL = imagesFolderURL.appendingPathComponent(imageURL.lastPathComponent)
                guard seenDestinationURLs.insert(destinationURL).inserted else {
                    return nil
                }
                return (source: imageURL, destination: destinationURL)
            }
            let skippedCount = imageURLs.count - imagesToRestore.count

            var restoredImages: [CapturedImage] = []
            for image in imagesToRestore {
                guard !Task.isCancelled else { return }
                do {
                    if await appData.fileService.fileExists(at: image.destination) {
                        try await appData.fileService.removeItem(at: image.destination)
                    }
                    try await appData.fileService.copyItem(at: image.source, to: image.destination)
                    restoredImages.append(CapturedImage(
                        name: image.source.deletingPathExtension().lastPathComponent,
                        fileURL: image.destination
                    ))
                } catch {
                    logger.error("Failed to restore archived image: \(error, privacy: .private)")
                }
            }
            let failedCount = imagesToRestore.count - restoredImages.count

            await MainActor.run {
                appData.images.append(contentsOf: restoredImages)
                var resultParts = ["Restored \(restoredImages.count) \(restoredImages.count == 1 ? "image" : "images")"]
                if skippedCount > 0 {
                    resultParts.append("\(skippedCount) already in Gallery")
                }
                if failedCount > 0 {
                    resultParts.append("\(failedCount) could not be restored")
                }
                restoreMessage = resultParts.joined(separator: ". ") + "."
                showRestoreConfirmation = true
                appData.hapticService.playNotification(type: failedCount > 0 ? .warning : .success)
            }
        } catch {
            await MainActor.run {
                restoreMessage = "Error: \(error.localizedDescription)"
                showRestoreConfirmation = true
            }
        }
    }

    private func deleteSelectedImages() async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        let docs = await appData.fileService.documentsDirectory
        let dateFolder = docs.appendingPathComponent(date)
        let imagesToDelete = Array(selectedImages)

        var deletedImages = Set<URL>()
        for imageURL in imagesToDelete {
            guard !Task.isCancelled else { return }
            do {
                try await appData.fileService.removeItem(at: imageURL)
                deletedImages.insert(imageURL)
            } catch {
                logger.error("Failed to delete archived image: \(error, privacy: .private)")
            }
        }

        let failedCount = imagesToDelete.count - deletedImages.count

        // Check if the archive folder is now empty and delete it
        if failedCount == 0 {
            do {
                let remainingFiles = try await appData.fileService.contentsOfDirectory(at: dateFolder)
                if remainingFiles.filter({ ["jpg", "png"].contains($0.pathExtension.lowercased()) }).isEmpty {
                    try await appData.fileService.removeItem(at: dateFolder)
                    await MainActor.run {
                        dismiss()
                    }
                    return
                }
            } catch {
                logger.error("Failed to check or delete empty archive folder: \(error, privacy: .private)")
            }
        }

        await MainActor.run {
            selectedImages.subtract(deletedImages)
            if failedCount == 0 {
                isMultiSelectMode = false
                appData.hapticService.playNotification(type: .success)
            } else {
                restoreMessage = "Deleted \(deletedImages.count) images. \(failedCount) could not be deleted and remain selected."
                showRestoreConfirmation = true
            }
        }
        await refreshImages()
    }

    private func refreshImages() async {
        let urls = await appData.getImagesForDate(date)
        await MainActor.run {
            self.images = urls
        }
    }

    @ViewBuilder
    private func archivedImageActionLabel(_ title: String, systemImage: String) -> some View {
        if isPerformingAction {
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Working")
        } else {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct ArchiveThumbnailView: View {
    let imageURL: URL
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onTap: () -> Void

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .overlay { ProgressView() }
            }

            if isMultiSelectMode {
                ZStack {
                    Color.black.opacity(isSelected ? 0.2 : 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .white)
                        .padding(6)
                        .shadow(radius: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
        .task(id: imageURL) {
            let url = imageURL
            let image = await Task.detached(priority: .userInitiated) {
                autoreleasepool {
                    DocumentImageProcessor.renderedImage(
                        for: CapturedImage(
                            name: url.deletingPathExtension().lastPathComponent,
                            fileURL: url
                        ),
                        maxPixelDimension: 320
                    )
                }
            }.value
            guard !Task.isCancelled else { return }
            uiImage = image
            loadFailed = image == nil
        }
    }
}

private struct ArchivedImageViewer: View {
    let imageURL: URL
    let onDelete: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let uiImage {
                FullscreenImageView(
                    image: CapturedImage(
                        name: imageURL.deletingPathExtension().lastPathComponent,
                        fileURL: imageURL
                    ),
                    uiImage: uiImage,
                    onDelete: onDelete,
                    onSave: onSave
                )
            } else if loadFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Could not load this archived image.")
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .foregroundStyle(.white)
            } else {
                ProgressView("Loading image...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .task(id: imageURL) {
            let url = imageURL
            let image = await Task.detached(priority: .userInitiated) {
                autoreleasepool {
                    DocumentImageProcessor.renderedImage(
                        for: CapturedImage(
                            name: url.deletingPathExtension().lastPathComponent,
                            fileURL: url
                        ),
                        maxPixelDimension: 2400
                    )
                }
            }.value
            guard !Task.isCancelled else { return }
            uiImage = image
            loadFailed = image == nil
        }
    }
}
