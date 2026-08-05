//
//  CameraView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct CameraGalleryRoute: Identifiable {
    let id = UUID()
    let outputMode: GalleryOutputMode

    init(captureMode: CameraCaptureMode) {
        outputMode = captureMode == .scan ? .singlePDF : .separateImages
    }
}

struct CameraView: View {
    let initialMode: CameraCaptureMode
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var galleryRoute: CameraGalleryRoute?

    var body: some View {
        let scannedCount = appData.images.filter(\.isDocumentScan).count
        let keptCount = appData.images.count - scannedCount
        return ScannerCaptureView(
            initialMode: initialMode,
            keptPhotoCount: keptCount,
            scannedPageCount: scannedCount,
            onScanCapture: { data, crop, captureFinished in
                Task {
                    let saved = await saveImageData(data, crop: crop, isDocumentScan: true)
                    await MainActor.run {
                        captureFinished(saved)
                    }
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
            onOpenGallery: { mode in
                galleryRoute = CameraGalleryRoute(captureMode: mode)
            },
            onCancel: { dismiss() }
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(item: $galleryRoute) { route in
            NavigationStack {
                GalleryView(initialOutputMode: route.outputMode)
                    .environmentObject(appData)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                galleryRoute = nil
                            }
                        }
                    }
            }
        }
    }

    func saveImage(
        image: UIImage,
        crop: DocumentCrop? = nil,
        isDocumentScan: Bool = false
    ) async {
        do {
            try await appData.saveCapturedImage(
                image,
                crop: crop,
                isDocumentScan: isDocumentScan
            )
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

    @discardableResult
    func saveImageData(
        _ data: Data,
        crop: DocumentCrop? = nil,
        isDocumentScan: Bool = false
    ) async -> Bool {
        do {
            try await appData.saveCapturedImageData(
                data,
                crop: crop,
                isDocumentScan: isDocumentScan
            )
            await MainActor.run {
                appData.hapticService.playNotification(type: .success)
            }
            return true
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to save image: \(error.localizedDescription)"
            }
            return false
        }
    }
}

#Preview {
    CameraView(initialMode: .photo)
        .environmentObject(AppData.preview)
}
