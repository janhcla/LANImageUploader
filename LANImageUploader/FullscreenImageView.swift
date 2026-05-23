//
//  FullscreenImageView.swift
//  LANImageUploader
//

import SwiftUI
import UIKit

struct FullscreenImageView: View {
    let image: CapturedImage
    let uiImage: UIImage
    let onDelete: () -> Void
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    // For Hero Transitions
    @State private var appearAnimation = false
    @State private var dragOffset: CGSize = .zero
    
    // Zoom State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Background with blur effect
            Color.black
                .opacity(appearAnimation ? 1.0 : 0.0)
                .ignoresSafeArea()
            
            // Image with Zoom & Pan & Dismiss Drag
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                .opacity(appearAnimation ? 1.0 : 0.0)
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .gesture(
                    scale == 1.0 ? 
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 100 {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                        }
                    : nil
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1.0 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            guard scale > 1.0 else { return }
                            lastOffset = offset
                        }
                )
            
            // Controls Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                GlassContainer(cornerRadius: 30) {
                    HStack(spacing: 40) {
                        Button(action: onSave) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                Text("Save")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                        }
                        
                        Button(action: onDelete) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                Text("Delete")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 20)
                .opacity(appearAnimation ? 1.0 : 0.0)
                .offset(y: appearAnimation ? 0 : 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }
}