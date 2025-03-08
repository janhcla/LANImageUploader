//
//  GalleryToolbarView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI

struct GalleryToolbarView: View {
    @Binding var isMultiSelectMode: Bool
    @Binding var selectedImages: Set<UUID>
    @Binding var isShowingNamingSheet: Bool
    @Binding var showDeleteConfirmation: Bool
    let saveAndUpload: () -> Void
    let isEmpty: Bool
    
    var body: some View {
        if !isEmpty {
            HStack {
                Button(action: { isShowingNamingSheet = true }) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(action: saveAndUpload) {
                    Label("Save and Upload Now", systemImage: "arrow.up.circle")
                }
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

