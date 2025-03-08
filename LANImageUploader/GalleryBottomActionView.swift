//
//  GalleryBottomActionView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI

struct GalleryBottomActionView: View {
    var onSaveToArchive: () -> Void
    var onBatchRenameUpload: () -> Void
    var isEmpty: Bool
    @Binding var showSaveConfirmation: Bool
    @ObservedObject var appData: AppData
    
    var body: some View {
        Group {
            if !isEmpty {
                VStack(spacing: 10) {
                    // Modified button implementation to use a simple approach
                    Button(action: onSaveToArchive) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to Archive")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(GrayButtonStyle())
                    
                    Button(action: onBatchRenameUpload) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Batch Rename & Upload")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(OrangeButtonStyle())
                }
                .padding()
            } else {
                Text("No images in gallery")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
}
