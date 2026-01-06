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
        BackgroundContainerView {
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
                .background(Color.clear)
                .navigationTitle("Capture Image")
                .fullScreenCover(
                    isPresented: $isShowingCamera,
                    onDismiss: {
                        if capturedImage != nil {
                            capturedImage = nil
                        }
                    }
                ) {
                    CameraPickerWrapper(image: $capturedImage)
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
    }

    func saveImage(image: UIImage) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "IMG_\(timestamp).jpg"
        
        do {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let fileURL = try appData.fileService.saveImage(data, fileName: fileName)
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

#Preview {
    CameraView()
        .environmentObject(AppData())
}
