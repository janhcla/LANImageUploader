//
//  ImageRowView.swift
//  LANImageUploader
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
        GlassContainer(cornerRadius: 18) {
            VStack(alignment: .center, spacing: 10) {
                AsyncImage(url: image.fileURL) { phase in
                    if let swiftUIImage = phase.image {
                        swiftUIImage
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                if isMultiSelectMode {
                                    selectionOverlay(isSelected: isSelected)
                                }
                            }
                    } else if phase.error != nil {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("Load Error")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(height: 160)
                    } else {
                        ProgressView()
                            .frame(height: 160)
                    }
                }
                
                Text(image.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .scaleEffect(isSelected ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture(perform: onTap)
        .contextMenu {
            if !isMultiSelectMode {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    func selectionOverlay(isSelected: Bool) -> some View {
        ZStack {
            Color.black.opacity(isSelected ? 0.2 : 0)
            
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .blue : .white.opacity(0.8))
                        .symbolEffect(.bounce, value: isSelected)
                        .padding(10)
                        .shadow(radius: 4)
                }
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}