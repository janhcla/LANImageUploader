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
    let onRotate: () -> Void
    let onDelete: () -> Void
    let onRetake: () -> Void

    @State private var uiImage: UIImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = item.capturedImage {
                    if let loadedImage = uiImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .rotationEffect(.degrees(Double(item.rotation.rawValue)))
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
                            .task(id: image.fileURL) {
                                await loadImage(from: image.fileURL)
                            }
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

            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .background(Circle().fill(Color.black.opacity(0.3)).padding(2))
                    .padding(8)
            }
        }
        .contextMenu {
            if item.capturedImage != nil {
                Button {
                    onRotate()
                } label: {
                    Label("Rotate", systemImage: "rotate.right")
                }

                Button {
                    onRetake()
                } label: {
                    Label("Retake", systemImage: "camera")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func loadImage(from url: URL) async {
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)
        }.value

        await MainActor.run {
            self.uiImage = image
        }
    }
}
