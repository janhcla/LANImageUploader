//
//  FullscreenImageView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 22/02/2025.
//

import SwiftUI
import UIKit

struct FullscreenImageView: View {
    let image: CapturedImage
    let uiImage: UIImage
    let onDelete: () -> Void
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var pinchCenter: CGPoint = .zero
    @State private var showSuccessToast = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let viewCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                Image(uiImage: uiImage)
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
                                        width: lastOffset.width - translation.x * (deltaScale - 1),
                                        height: lastOffset.height - translation.y * (deltaScale - 1)
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
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                Spacer()
                HStack {
                    Button(action: {
                        // Show success toast
                        showSuccessToast = true

                        // First call onSave handler
                        onSave()

                        // Dismiss with delay to show the toast
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 44, height: 44)

                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)

                    Spacer()

                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 44, height: 44)

                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 8)
            }
            .padding()
            .zIndex(2)

            // Success toast
            if showSuccessToast {
                VStack {
                    Spacer()
                    Text("Image saved to archive")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: showSuccessToast)
                .zIndex(3)
            }
        }
    }
}
