//
//  GalleryItemView.swift
//  LANImageUploader
//

import SwiftUI
import UIKit

struct GalleryItemView: View {
    let index: Int
    let item: GalleryItem
    let isSelected: Bool
    let isMultiSelectMode: Bool

    let onTap: () -> Void
    let onUpload: () -> Void
    let onRotate: () -> Void
    let onEditCrop: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onRetake: () -> Void

    @State private var uiImage: UIImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = item.capturedImage {
                    if let loadedImage = uiImage {
                        thumbnailImage(loadedImage, isDocumentScan: image.isDocumentScan)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .overlay(alignment: .bottomLeading) {
                                Text(image.name)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(8)
                            }
                    } else {
                        // Loading state
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 150)
                            .overlay(ProgressView())
                    }

                } else {
                    // Empty slot
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                        )
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                onTap()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibleItemName)
            .accessibilityValue(accessibleItemValue)
            .accessibilityHint(isMultiSelectMode ? "Double tap to change selection" : "Double tap to open full screen")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Upload", onUpload)
            .accessibilityAction(named: "Rotate", onRotate)
            .accessibilityAction(named: "Edit Crop", onEditCrop)
            .accessibilityAction(named: "Rename", onRename)
            .accessibilityAction(named: "Retake", onRetake)
            .accessibilityAction(named: "Delete", onDelete)
            .task(id: imageReloadID) {
                await loadImage()
            }
            .onDisappear {
                uiImage = nil
            }

            // Index badge
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
                .padding(8)
                .offset(x: -8, y: 8) // align to top left
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityHidden(true)

            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .background(Circle().fill(Color.black.opacity(0.3)).padding(2))
                    .padding(8)
                    .accessibilityHidden(true)
            } else {
                Menu {
                    itemActions
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.48), in: Circle())
                }
                .accessibilityLabel("Actions for \(item.capturedImage?.name ?? "empty position")")
                .padding(6)
            }
        }
        .contextMenu {
            itemActions
        }
    }

    @ViewBuilder
    private var itemActions: some View {
        if item.capturedImage != nil {
            Button(action: onUpload) {
                Label("Upload", systemImage: "square.and.arrow.up")
            }
            Button(action: onRotate) {
                Label("Rotate", systemImage: "rotate.right")
            }
            Button(action: onEditCrop) {
                Label("Edit Crop", systemImage: "crop.rotate")
            }
            Button(action: onRename) {
                Label("Rename Photo", systemImage: "pencil")
            }
            Button(action: onRetake) {
                Label("Retake", systemImage: "camera")
            }
        }
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func thumbnailImage(_ image: UIImage, isDocumentScan: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isDocumentScan ? 0.16 : 0.08))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var imageReloadID: String {
        guard let image = item.capturedImage else { return item.id.uuidString }
        return "\(image.id.uuidString)-\(image.fileURL.path)-\(String(describing: image.crop))-\(item.rotation.rawValue)"
    }

    private var accessibleItemName: String {
        item.capturedImage?.name ?? "Empty gallery position \(index + 1)"
    }

    private var accessibleItemValue: String {
        if isMultiSelectMode {
            return isSelected ? "Selected" : "Not selected"
        }
        return "Position \(index + 1)"
    }

    private func loadImage() async {
        guard let capturedImage = item.capturedImage else {
            await MainActor.run {
                self.uiImage = nil
            }
            return
        }

        let image: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            autoreleasepool {
                DocumentImageProcessor.renderedImage(
                    for: capturedImage,
                    rotation: item.rotation,
                    maxPixelDimension: 640
                )
            }
        }.value

        await MainActor.run {
            self.uiImage = image
        }
    }
}
