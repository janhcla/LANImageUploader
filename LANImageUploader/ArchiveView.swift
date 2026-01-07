//
//  ArchiveView.swift
//  LANImageUploader
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
    @State private var archivedDates: [String] = []

    private var hasArchives: Bool {
        !archivedDates.isEmpty
    }

    var body: some View {
        BackgroundContainerView {
            NavigationStack {
                List {
                    ForEach(archivedDates, id: \.self) { date in
                        archiveRow(for: date)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                                withAnimation(.spring()) {
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
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .green))

                                    Button(action: {
                                        showDeleteSelectedConfirmation = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
                                }
                            } else if !isMultiSelectMode {
                                Button(action: {
                                    showDeleteAllConfirmation = true
                                }) {
                                    Label("Delete All Archives", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
                            }
                        }
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .alert("Confirmation", isPresented: $showDeleteAllConfirmation) {
                    Button("Yes, Delete All", role: .destructive) { Task { await deleteAllArchives() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Do you really want to delete all images in the archive? This cannot be undone.")
                }
                .alert("Delete Selected", isPresented: $showDeleteSelectedConfirmation) {
                    Button("Delete", role: .destructive) { Task { await deleteSelectedArchives() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete the selected archives permanently?")
                }
                .alert("Restore Result", isPresented: $showRestoreConfirmation) {
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
                }
                
                HStack(spacing: 16) {
                    Button("Cancel") { showRenameSheet = false }
                        .buttonStyle(GrayButtonStyle())
                    
                    Button("Save") {
                        saveRenamedArchive()
                        showRenameSheet = false
                    }
                    .buttonStyle(BlueButtonStyle())
                }
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
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
                        .symbolEffect(.bounce, value: isSelected)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        guard !dateToRename.isEmpty, !newArchiveName.isEmpty else { return }
        customArchiveNames[dateToRename] = newArchiveName
        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: Constants.UserDefaults.archiveCustomNames)
        }
        appData.hapticService.playNotification(type: .success)
        dateToRename = ""
    }

    private func loadCustomArchiveNames() {
        if let savedData = UserDefaults.standard.data(forKey: Constants.UserDefaults.archiveCustomNames),
            let decoded = try? JSONDecoder().decode([String: String].self, from: savedData)
        {
            customArchiveNames = decoded
        }
    }

    private func restoreSelectedArchives() async {
        appData.hapticService.playLiquidBounce()
        var successCount = 0
        var failureCount = 0

        for date in selectedDates {
            let images = await appData.getImagesForDate(date)
            let docs = await appData.fileService.documentsDirectory
            let imagesFolderURL = docs.appendingPathComponent("images")

            do {
                try await appData.fileService.createDirectory(at: imagesFolderURL)

                for imageURL in images {
                    let destinationURL = imagesFolderURL.appendingPathComponent(
                        imageURL.lastPathComponent)

                    if !appData.images.contains(where: { $0.fileURL == destinationURL }) {
                        try? await appData.fileService.removeItem(at: destinationURL)
                        try await appData.fileService.copyItem(at: imageURL, to: destinationURL)
                        let capturedImage = CapturedImage(
                            name: imageURL.deletingPathExtension().lastPathComponent,
                            fileURL: destinationURL)
                        await MainActor.run {
                            appData.images.append(capturedImage)
                        }
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                }
            } catch {
                failureCount += 1
            }
        }

        await MainActor.run {
            restoreMessage = "Restored \(successCount) images" + (failureCount > 0 ? " (\(failureCount) already in gallery)" : "")
            showRestoreConfirmation = true
            selectedDates.removeAll()
            isMultiSelectMode = false
            appData.hapticService.playNotification(type: .success)
        }
    }

    private func deleteSelectedArchives() async {
        let docs = await appData.fileService.documentsDirectory
        for date in selectedDates {
            let archiveURL = docs.appendingPathComponent(date)
            do {
                try await appData.fileService.removeItem(at: archiveURL)
                customArchiveNames.removeValue(forKey: date)
            } catch {
                print("Failed to delete archive \(date): \(error)")
            }
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
        let archives = await appData.getArchivedDates()
        let docs = await appData.fileService.documentsDirectory
        for archive in archives {
            let archiveURL = docs.appendingPathComponent(archive)
            try? await appData.fileService.removeItem(at: archiveURL)
            customArchiveNames.removeValue(forKey: archive)
        }

        if let encoded = try? JSONEncoder().encode(customArchiveNames) {
            UserDefaults.standard.set(encoded, forKey: Constants.UserDefaults.archiveCustomNames)
        }
        
        await refreshArchivedDates()
        appData.hapticService.playNotification(type: .success)
    }
}

struct ArchivedImagesView: View {
    let date: String
    var displayName: String
    @EnvironmentObject var appData: AppData
    @State private var selectedImages: Set<URL> = []
    @State private var isMultiSelectMode = false
    @State private var selectedImageURL: IdentifiableURL? = nil
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage = ""
    @State private var showDeleteSelectedConfirmation = false
    @State private var images: [URL] = []

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
                                withAnimation {
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
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .green))

                                    Button(action: {
                                        showDeleteSelectedConfirmation = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LiquidButtonStyle(backgroundColor: .red))
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
                            Label("Restore All Images", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiquidButtonStyle(backgroundColor: .green))
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
                .onAppear {
                    Task { await refreshImages() }
                }
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
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
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
                    .onTapGesture {
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
            } else {
                Rectangle().fill(.secondary.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
            }
        }
    }

    func restoreAllImages() async {
        let images = await appData.getImagesForDate(date)
        await restoreImages(images)
    }

    func restoreSelectedImages() async {
        await restoreImages(Array(selectedImages))
        await MainActor.run {
            selectedImages.removeAll()
            isMultiSelectMode = false
        }
    }

    private func restoreImages(_ imageURLs: [URL]) async {
        let docs = await appData.fileService.documentsDirectory
        let imagesFolderURL = docs.appendingPathComponent("images")
        var successCount = 0

        do {
            try await appData.fileService.createDirectory(at: imagesFolderURL)
            for imageURL in imageURLs {
                let destinationURL = imagesFolderURL.appendingPathComponent(
                    imageURL.lastPathComponent)
                if !appData.images.contains(where: { $0.fileURL == destinationURL }) {
                    try? await appData.fileService.removeItem(at: destinationURL)
                    try await appData.fileService.copyItem(at: imageURL, to: destinationURL)
                    let capturedImage = CapturedImage(
                        name: imageURL.deletingPathExtension().lastPathComponent,
                        fileURL: destinationURL)
                    await MainActor.run {
                        appData.images.append(capturedImage)
                    }
                    successCount += 1
                }
            }
            await MainActor.run {
                restoreMessage = "Restored \(successCount) images"
                showRestoreConfirmation = true
                appData.hapticService.playNotification(type: .success)
            }
        } catch {
            await MainActor.run {
                restoreMessage = "Error: \(error.localizedDescription)"
                showRestoreConfirmation = true
            }
        }
    }

    private func deleteSelectedImages() async {
        for imageURL in selectedImages {
            try? await appData.fileService.removeItem(at: imageURL)
        }

        await MainActor.run {
            selectedImages.removeAll()
            isMultiSelectMode = false
            appData.hapticService.playNotification(type: .success)
        }
        await refreshImages()
    }

    private func refreshImages() async {
        let urls = await appData.getImagesForDate(date)
        await MainActor.run {
            self.images = urls
        }
    }
}