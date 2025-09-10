//
//  ImageRowView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI
import UIKit

struct ImageRowView: View {
    let image: CapturedImage
    let isMultiSelectMode: Bool
    let isSelected: Bool
    var onTap: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .center) {
            AsyncImage(url: image.fileURL) { phase in
                if let swiftUIImage = phase.image {
                    swiftUIImage
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxHeight: 200)
                        .overlay {
                            if isMultiSelectMode {
                                selectionOverlay(isSelected: isSelected)
                            } else {
                                EmptyView()
                            }
                        }
                } else if phase.error != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                }
            }
            Text(image.name)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture(perform: onTap)
        .contextMenu {
            if !isMultiSelectMode {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(
                    role: .destructive,
                    action: onDelete
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    func selectionOverlay(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .blue : .gray)
            .padding(8)
            .background(Circle().fill(Color.white.opacity(0.8)))
            .offset(x: -8, y: -8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}
