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
                    
                    GlassContainer(cornerRadius: 24) {
                        VStack(spacing: 20) {
                            Image(systemName: "camera.shutter.button.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .symbolEffect(.bounce, value: isShowingCamera)
                            
                            Text("Ready to Capture")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Button(action: { 
                                appData.hapticService.playLiquidBounce()
                                isShowingCamera = true 
                            }) {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(BlueButtonStyle())
                        }
                    }
                    .padding(30)
                    
                    Spacer()
                }
                .navigationTitle("Capture")
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
                        Task {
                            await saveImage(image: image)
                        }
                        capturedImage = nil
                        appData.hapticService.playNotification(type: .success)
                    }
                }
                .navigationDestination(isPresented: $navigateToGallery) {
                    GalleryView().environmentObject(appData)
                }
                .safeAreaInset(edge: .bottom) {
                    if !appData.images.isEmpty {
                        Button(action: { 
                            appData.hapticService.playSelection()
                            navigateToGallery = true 
                        }) {
                            Label("View Gallery", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiquidButtonStyle(backgroundColor: .green))
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }

    func saveImage(image: UIImage) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "IMG_\(timestamp).jpg"
        
        let quad = await DocumentDetectionService.shared.detectDocument(in: image)

        do {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let fileURL = try await appData.fileService.saveImage(data, fileName: fileName)
                let captured = CapturedImage(
                    name: fileName.removingSuffix(".jpg"), fileURL: fileURL, documentQuad: quad)
                await MainActor.run {
                    appData.images.append(captured)
                }
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to save image: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppData.preview)
}
