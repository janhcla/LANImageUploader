//
//  CameraView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct CameraView: View {
    let initialMode: CameraCaptureMode
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var navigateToGallery = false

    var body: some View {
        let scannedCount = appData.images.filter(\.isDocumentScan).count
        let keptCount = appData.images.count - scannedCount
        return ScannerCaptureView(
            initialMode: initialMode,
            keptPhotoCount: keptCount,
            scannedPageCount: scannedCount,
            onScanCapture: { image, crop in
                Task {
                    await saveImage(image: image, crop: crop)
                }
            },
            onKeepPhoto: { image in
                Task {
                    await saveImage(image: image)
                }
            },
            onCountdownTick: {
                appData.hapticService.playImpact(style: .medium)
            },
            onOpenGallery: {
                navigateToGallery = true
            },
            onCancel: { dismiss() }
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $navigateToGallery) {
            NavigationStack {
                GalleryView()
                    .environmentObject(appData)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                navigateToGallery = false
                            }
                        }
                    }
            }
        }
    }

    func saveImage(image: UIImage, crop: DocumentCrop? = nil) async {
        do {
            try await appData.saveCapturedImage(image, crop: crop)
            await MainActor.run {
                appData.hapticService.playNotification(type: .success)
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
    CameraView(initialMode: .photo)
        .environmentObject(AppData.preview)
}
