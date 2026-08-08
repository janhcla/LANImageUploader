//
//  MultiSelectToolbarView.swift
//  LANImageUploader
//

import SwiftUI

struct MultiSelectToolbarView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onUpload: () -> Void
    var onDelete: () -> Void
    var onRename: () -> Void
    var onRotate: () -> Void
    var onArchive: () -> Void
    
    var body: some View {
        GlassContainer(cornerRadius: 20) {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    actionButtons
                }
                .scrollIndicators(.visible)
            } else {
                actionButtons
            }
        }
        .accessibilityLabel("Actions for \(appData.selectedImageIDs.count) selected items")
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(systemImage: "square.and.arrow.up", title: "Upload", color: .green, action: onUpload)
            ActionButton(systemImage: "trash", title: "Delete", color: .red, action: onDelete)
            ActionButton(systemImage: "pencil.and.outline", title: "Rename", color: .blue, action: onRename)
            ActionButton(systemImage: "rotate.right", title: "Rotate", color: .orange, action: onRotate)
            ActionButton(systemImage: "archivebox", title: "Archive", color: .teal, action: onArchive)
        }
        .padding(.horizontal, 10)
    }
}

private struct ActionButton: View {
    let systemImage: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            .frame(minWidth: 52, minHeight: 44)
        }
        .buttonStyle(.plain) // Use plain to not conflict with the GlassContainer
        .accessibilityLabel(title)
    }
}
