//
//  CameraView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct CameraView: View {
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var navigateToGallery = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Button(action: { isShowingCamera = true }) {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Capture Image")
            .sheet(
                isPresented: $isShowingCamera,
                onDismiss: {
                    if capturedImage != nil {
                        capturedImage = nil
                    }
                }
            ) {
                CameraPicker(image: $capturedImage)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: capturedImage) {
                if let image = capturedImage {
                    saveImage(image: image)
                    capturedImage = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .navigationDestination(isPresented: $navigateToGallery) {
                GalleryView().environmentObject(appData)
            }
            .safeAreaInset(edge: .bottom) {
                if !appData.images.isEmpty {
                    Button(action: { navigateToGallery = true }) {
                        Label("View Gallery", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding()
                }
            }
        }
    }

    func saveImage(image: UIImage) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "IMG_\(timestamp).jpg"
        let imagesFolderURL = appData.documentsDirectory.appendingPathComponent("images")
        do {
            try FileManager.default.createDirectory(
                at: imagesFolderURL, withIntermediateDirectories: true)
            let fileURL = imagesFolderURL.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                let captured = CapturedImage(
                    name: fileName.removingSuffix(".jpg"), fileURL: fileURL)
                appData.images.append(captured)
            }
        } catch {
            showError = true
            errorMessage = "Failed to save image: \(error.localizedDescription)"
        }
    }
}
