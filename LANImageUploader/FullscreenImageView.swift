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
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                    }
                }
                Spacer()
                HStack {
                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.green))
                    }
                    .padding(.leading, 16)

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(.trailing, 16)
                }
            }
            .padding()
            .zIndex(2)
        }
    }
}

//import SwiftUI
//import UIKit
//
//struct FullscreenImageView: View {
//    let image: CapturedImage
//    let uiImage: UIImage
//    let onDelete: () -> Void
//    @Environment(\.dismiss) var dismiss
//
//    // States for zoom and pan
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//    @State private var offset: CGSize = .zero
//    @State private var lastOffset: CGSize = .zero
//    @State private var pinchCenter: CGPoint = .zero  // updated continuously during pinch
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            GeometryReader { geo in
//                let viewCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
//
//                Image(uiImage: uiImage)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .scaleEffect(scale)
//                    .offset(offset)
//                    // Panning gesture for one-finger drag
//                    .gesture(
//                        DragGesture(minimumDistance: 10)
//                            .onChanged { gesture in
//                                offset = CGSize(width: lastOffset.width + gesture.translation.width,
//                                                height: lastOffset.height + gesture.translation.height)
//                            }
//                            .onEnded { _ in
//                                lastOffset = offset
//                            }
//                    )
//                    // Simultaneous gesture for pinch-to-zoom that tracks the pinch center
//                    .simultaneousGesture(
//                        SimultaneousGesture(
//                            MagnificationGesture()
//                                .onChanged { value in
//                                    // Compute the new scale
//                                    let newScale = lastScale * value
//                                    let deltaScale = newScale / lastScale
//
//                                    // Compute vector from view center to the current pinch center
//                                    let translation = CGPoint(x: pinchCenter.x - viewCenter.x,
//                                                              y: pinchCenter.y - viewCenter.y)
//
//                                    // Adjust the offset so that the pinch center stays in place
//                                    let newOffset = CGSize(
//                                        width: lastOffset.width - translation.x * (deltaScale - 1),
//                                        height: lastOffset.height - translation.y * (deltaScale - 1)
//                                    )
//
//                                    scale = newScale
//                                    offset = newOffset
//                                }
//                                .onEnded { _ in
//                                    lastScale = scale
//                                    lastOffset = offset
//                                },
//                            // This drag gesture (with zero minimum distance) captures the pinch center
//                            DragGesture(minimumDistance: 0)
//                                .onChanged { gesture in
//                                    // Update pinchCenter in the coordinate space of the GeometryReader
//                                    pinchCenter = gesture.location
//                                }
//                        )
//                    )
//                    .onAppear {
//                        print("Rendering UIImage in fullscreen: \(image.fileURL)")
//                        // Initialize pinchCenter to the view center
//                        pinchCenter = viewCenter
//                    }
//            }
//
//            // Overlay buttons
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: { dismiss() }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title3)
//                            .foregroundColor(.white)
//                            .padding(6)
//                            .background(Circle().fill(Color.black.opacity(0.7)))
//                    }
//                }
//                Spacer()
//                HStack {
//                    Spacer()
//                    Button(action: onDelete) {
//                        Image(systemName: "trash")
//                            .font(.body)
//                            .foregroundColor(.white)
//                            .padding(6)
//                            .background(Circle().fill(Color.red))
//                    }
//                }
//            }
//            .padding()
//            .zIndex(2)
//        }
//        .onDisappear {
//            print("Fullscreen view disappeared")
//        }
//    }
//}
