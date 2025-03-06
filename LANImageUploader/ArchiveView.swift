//
//  ArchiveView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI

// Custom struct to make URL Identifiable
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ArchiveView: View {
    @EnvironmentObject var appData: AppData
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

    private var hasArchives: Bool {
        !appData.getArchivedDates().isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(appData.getArchivedDates(), id: \.self) { date in
                    archiveRow(for: date)
                }
            }
            .navigationTitle("Archived Images")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if hasArchives {
                        Button(isMultiSelectMode ? "Done" : "Select") {
                            isMultiSelectMode.toggle()
                            if !isMultiSelectMode {
                                selectedDates.removeAll()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if isMultiSelectMode && !selectedDates.isEmpty {
                        HStack {
                            Button(action: restoreSelectedArchives) {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button(action: {
                                showDeleteSelectedConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasArchives && !isMultiSelectMode {
                    Button(action: {
                        showDeleteAllConfirmation = true
                    }) {
                        Label("Delete ALL", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding()
                }
            }
            .alert("Confirmation", isPresented: $showDeleteAllConfirmation) {
                Button("Yes", role: .destructive) { deleteAllArchives() }
                Button("No", role: .cancel) {}
            } message: {
                Text(
                    "Do you really want to delete all images in the archive - this action cannot be undone"
                )
            }
            .alert("Confirmation", isPresented: $showDeleteSelectedConfirmation) {
                Button("Yes", role: .destructive) { deleteSelectedArchives() }
                Button("No", role: .cancel) {}
            } message: {
                Text(
                    "Do you really want to delete the selected archives? This action cannot be undone."
                )
            }
            .alert("Confirmation", isPresented: $showRestoreConfirmation) {
                Button("OK") { showRestoreConfirmation = false }
            } message: {
                Text(restoreMessage)
            }
            .sheet(isPresented: $showRenameSheet) {
                renameArchiveSheet
            }
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
        }
    }

    @ViewBuilder
    var renameArchiveSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter new name for archive")) {
                    TextField("New name", text: $newArchiveName)
                }
            }
            .navigationTitle("Rename Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showRenameSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRenamedArchive()
                        showRenameSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    func archiveRow(for date: String) -> some View {
        let isSelected = selectedDates.contains(date)
        let displayName = customArchiveNames[date] ?? date

        HStack {
            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .padding(.trailing, 5)
            }

            Button(action: {
                if isMultiSelectMode {
                    if isSelected {
                        selectedDates.remove(date)
                    } else {
                        selectedDates.insert(date)
                    }
                } else {
                    selectedDate = date
                }
            }) {
                Text(displayName)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isMultiSelectMode {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
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
        .swipeActions(edge: .leading) {
            Button {
                selectedDates = [date]
                restoreSelectedArchives()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.green)
        }
    }

    private func saveRenamedArchive() {
        guard !dateToRename.isEmpty, !newArchiveName.isEmpty else { return }

        // Update the custom name
        customArchiveNames[dateToRename] = newArchiveName

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: "archiveCustomNames")
        }

        dateToRename = ""
    }

    private func loadCustomArchiveNames() {
        if let savedData = UserDefaults.standard.data(forKey: "archiveCustomNames"),
            let decoded = try? JSONDecoder().decode([String: String].self, from: savedData)
        {
            customArchiveNames = decoded
        }
    }

    private func restoreSelectedArchives() {
        var successCount = 0
        var failureCount = 0

        for date in selectedDates {
            let images = appData.getImagesForDate(date)
            let fileManager = FileManager.default
            let imagesFolderURL = appData.documentsDirectory.appendingPathComponent("images")

            do {
                try fileManager.createDirectory(
                    at: imagesFolderURL, withIntermediateDirectories: true)

                for imageURL in images {
                    let destinationURL = imagesFolderURL.appendingPathComponent(
                        imageURL.lastPathComponent)

                    if !appData.images.contains(where: { $0.fileURL == destinationURL }) {
                        try fileManager.copyItem(at: imageURL, to: destinationURL)
                        let capturedImage = CapturedImage(
                            name: imageURL.deletingPathExtension().lastPathComponent,
                            fileURL: destinationURL)
                        appData.images.append(capturedImage)
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                }
            } catch {
                print("Failed to restore archive \(date): \(error)")
                failureCount += 1
            }
        }

        restoreMessage =
            "Restored \(successCount) images"
            + (failureCount > 0 ? " (\(failureCount) already existed)" : "")
        showRestoreConfirmation = true
        selectedDates.removeAll()
        isMultiSelectMode = false
    }

    private func deleteSelectedArchives() {
        let fileManager = FileManager.default

        for date in selectedDates {
            let archiveURL = appData.documentsDirectory.appendingPathComponent(date)
            do {
                try fileManager.removeItem(at: archiveURL)
                print("Deleted archive: \(archiveURL.path)")

                // Also remove custom name if it exists
                customArchiveNames.removeValue(forKey: date)
            } catch {
                print("Failed to delete archive \(date): \(error)")
            }
        }

        // Save updated custom names
        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: "archiveCustomNames")
        }

        selectedDates.removeAll()
        isMultiSelectMode = false
    }

    private func deleteAllArchives() {
        let archives = appData.getArchivedDates()
        let fileManager = FileManager.default
        for archive in archives {
            let archiveURL = appData.documentsDirectory.appendingPathComponent(archive)
            do {
                try fileManager.removeItem(at: archiveURL)
                print("Deleted archive: \(archiveURL.path)")

                // Also remove custom name
                customArchiveNames.removeValue(forKey: archive)
            } catch {
                print("Failed to delete archive \(archive): \(error)")
            }
        }

        // Save updated custom names
        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: "archiveCustomNames")
        }
    }
}

struct ArchivedImagesView: View {
    let date: String
    var displayName: String
    @EnvironmentObject var appData: AppData
    @State private var selectedImages: Set<URL> = []
    @State private var isMultiSelectMode = false
    @State private var selectedImageURL: IdentifiableURL?  // Updated to IdentifiableURL
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage = ""
    @State private var showDeleteSelectedConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(appData.getImagesForDate(date), id: \.self) { imageURL in
                        imageThumbnail(for: imageURL)
                    }
                }
                .padding()
            }
            .navigationTitle("Images from \(displayName)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isMultiSelectMode ? "Done" : "Select") {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode { selectedImages.removeAll() }
                    }
                }
            }
            .fullScreenCover(item: $selectedImageURL) { identifiableURL in
                FullscreenArchivedImageView(imageURL: identifiableURL.url)
            }
            .safeAreaInset(edge: .bottom) {
                if isMultiSelectMode && !selectedImages.isEmpty {
                    VStack {
                        HStack(spacing: 20) {
                            Button(action: restoreSelectedImages) {
                                Label("Restore to Gallery", systemImage: "arrow.uturn.backward")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button(action: {
                                showDeleteSelectedConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                } else if !isMultiSelectMode {
                    Button(action: restoreAllImages) {
                        Label("Restore Images", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding()
                }
            }
            .alert("Confirmation", isPresented: $showRestoreConfirmation) {
                Button("OK") { showRestoreConfirmation = false }
            } message: {
                Text(restoreMessage)
            }
            .alert("Confirmation", isPresented: $showDeleteSelectedConfirmation) {
                Button("Yes", role: .destructive) { deleteSelectedImages() }
                Button("No", role: .cancel) {}
            } message: {
                Text(
                    "Do you really want to delete all selected images in the archive - this action cannot be undone"
                )
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    func imageThumbnail(for imageURL: URL) -> some View {
        let isSelected = selectedImages.contains(imageURL)
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        if isMultiSelectMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .gray)
                                .padding(4)
                                .background(Circle().fill(Color.white.opacity(0.8)))
                        }
                    }
                    .onTapGesture {
                        if !isMultiSelectMode {
                            selectedImageURL = IdentifiableURL(url: imageURL)
                        } else {
                            if selectedImages.contains(imageURL) {
                                selectedImages.remove(imageURL)
                            } else {
                                selectedImages.insert(imageURL)
                            }
                        }
                    }
            } else if phase.error != nil {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
    }

    func restoreAllImages() {
        let images = appData.getImagesForDate(date)
        restoreImages(images)
    }

    func restoreSelectedImages() {
        restoreImages(Array(selectedImages))
        selectedImages.removeAll()
        isMultiSelectMode = false
    }

    private func restoreImages(_ imageURLs: [URL]) {
        let fileManager = FileManager.default
        let imagesFolderURL = appData.documentsDirectory.appendingPathComponent("images")
        var canRestore = true
        var restoredCount = 0

        do {
            try fileManager.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)
            for imageURL in imageURLs {
                let destinationURL = imagesFolderURL.appendingPathComponent(
                    imageURL.lastPathComponent)
                if !appData.images.contains(where: { $0.fileURL == destinationURL }) {
                    try fileManager.copyItem(at: imageURL, to: destinationURL)
                    let capturedImage = CapturedImage(
                        name: imageURL.deletingPathExtension().lastPathComponent,
                        fileURL: destinationURL)
                    appData.images.append(capturedImage)
                    restoredCount += 1
                } else {
                    canRestore = false
                }
            }
            showRestoreConfirmation(
                canRestore ? "Image(s) restored" : "Cannot restore, images already in the gallery")
            print("Restored \(restoredCount) images")
        } catch {
            print("Failed to restore images: \(error)")
            showRestoreConfirmation("Failed to restore images: \(error.localizedDescription)")
        }
    }

    private func deleteSelectedImages() {
        let fileManager = FileManager.default
        let dateFolder = appData.documentsDirectory.appendingPathComponent(date)

        // Delete selected images
        for imageURL in selectedImages {
            do {
                try fileManager.removeItem(at: imageURL)
                print("Deleted image: \(imageURL.path)")
            } catch {
                print("Failed to delete image: \(error)")
            }
        }

        // Check if the archive folder is now empty
        do {
            let remainingFiles = try fileManager.contentsOfDirectory(
                at: dateFolder, includingPropertiesForKeys: nil)
            let imageFiles = remainingFiles.filter {
                ["jpg", "png"].contains($0.pathExtension.lowercased())
            }

            // If no images left in the folder, delete the archive folder
            if imageFiles.isEmpty {
                try fileManager.removeItem(at: dateFolder)
                print("Deleted empty archive folder: \(date)")
                // Dismiss the view since the archive folder no longer exists
                dismiss()
                return
            }
        } catch {
            print("Error checking for empty archive: \(error)")
        }

        selectedImages.removeAll()
        isMultiSelectMode = false
    }

    private func showRestoreConfirmation(_ message: String) {
        restoreMessage = message
        showRestoreConfirmation = true
    }
}

struct FullscreenArchivedImageView: View {
    let imageURL: URL
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage = ""

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var pinchCenter: CGPoint = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let viewCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { gesture in
                                        offset = CGSize(
                                            width: lastOffset.width + gesture.translation.width,
                                            height: lastOffset.height + gesture.translation.height)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .simultaneousGesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value
                                            let deltaScale = newScale / lastScale
                                            let translation = CGPoint(
                                                x: pinchCenter.x - viewCenter.x,
                                                y: pinchCenter.y - viewCenter.y)
                                            let newOffset = CGSize(
                                                width: lastOffset.width - translation.x
                                                    * (deltaScale - 1),
                                                height: lastOffset.height - translation.y
                                                    * (deltaScale - 1)
                                            )
                                            scale = newScale
                                            offset = newOffset
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            lastOffset = offset
                                        },
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            pinchCenter = gesture.location
                                        }
                                )
                            )
                            .onAppear {
                                pinchCenter = viewCenter
                            }
                    } else if phase.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                    }
                }
            }

            // UI controls overlay
            VStack {
                // Top right dismiss button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                    }
                }
                .padding()

                Spacer()

                // Bottom buttons
                HStack {
                    // Bottom left restore button
                    Button(action: { restoreImage() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.green))
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Bottom right delete button
                    Button(action: { deleteImage() }) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom)
            }
        }
        .alert(restoreMessage, isPresented: $showRestoreConfirmation) {
            Button("OK") { showRestoreConfirmation = false }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func restoreImage() {
        let fileManager = FileManager.default
        let imagesFolderURL = appData.documentsDirectory.appendingPathComponent("images")
        do {
            try fileManager.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)
            let destinationURL = imagesFolderURL.appendingPathComponent(imageURL.lastPathComponent)
            if !appData.images.contains(where: { $0.fileURL == destinationURL }) {
                try fileManager.copyItem(at: imageURL, to: destinationURL)
                let capturedImage = CapturedImage(
                    name: imageURL.deletingPathExtension().lastPathComponent,
                    fileURL: destinationURL)
                appData.images.append(capturedImage)
                showRestoreConfirmation("Image restored")
            } else {
                showRestoreConfirmation("Cannot restore, image already in the gallery")
            }
        } catch {
            print("Failed to restore image: \(error)")
            showRestoreConfirmation("Failed to restore image: \(error.localizedDescription)")
        }
    }

    private func deleteImage() {
        let fileManager = FileManager.default
        let archiveFolder = imageURL.deletingLastPathComponent()
        let archiveFolderName = archiveFolder.lastPathComponent

        do {
            // Delete the image file
            try fileManager.removeItem(at: imageURL)
            print("Deleted image: \(imageURL.path)")

            // Check if the archive is now empty
            let contents = try fileManager.contentsOfDirectory(
                at: archiveFolder, includingPropertiesForKeys: nil)
            let imageFiles = contents.filter {
                ["jpg", "png"].contains($0.pathExtension.lowercased())
            }

            // If no images left, delete the archive folder
            if imageFiles.isEmpty {
                try fileManager.removeItem(at: archiveFolder)
                print("Deleted empty archive: \(archiveFolderName)")
            }

            // Dismiss the view after deletion
            dismiss()
        } catch {
            print("Failed to delete image \(imageURL.path): \(error)")
        }
    }

    private func showRestoreConfirmation(_ message: String) {
        restoreMessage = message
        showRestoreConfirmation = true
    }
}
