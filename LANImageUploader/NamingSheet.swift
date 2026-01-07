//
//  NamingSheet.swift
//  LANImageUploader
//

import SwiftUI
import VisionKit
import Vision
import UIKit
import Foundation

struct NamingSheet: View {
    @Binding var imageName: String
    @EnvironmentObject var appData: AppData
    var onSave: () -> Void
    var saveButtonLabel: String
    @Environment(\.dismiss) var dismiss
    @State private var isScanningOCR = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 24) {
                Text("Name Your Image")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top)

                GlassContainer(cornerRadius: 16) {
                    TextField("Enter name...", text: $appData.imageName)
                        .font(.body)
                        .submitLabel(.done)
                        .focused($isTextFieldFocused)
                        .overlay(alignment: .trailing) {
                            HStack {
                                if !appData.imageName.isEmpty {
                                    Button(action: { 
                                        appData.hapticService.playSelection()
                                        appData.imageName = "" 
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                
                                Button(action: {
                                    appData.hapticService.playSelection()
                                    isTextFieldFocused = false
                                    withAnimation(.spring()) {
                                        isScanningOCR.toggle()
                                    }
                                }) {
                                    Image(systemName: "camera.viewfinder")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                }

                if isScanningOCR {
                    GlassContainer(cornerRadius: 20) {
                        OCRCameraView(isScanning: $isScanningOCR, height: 260)
                            .frame(height: 260)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Button(action: {
                    imageName = appData.imageName
                    appData.hapticService.playLiquidBounce()
                    onSave()
                    dismiss()
                }) {
                    Label(saveButtonLabel, systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BlueButtonStyle())
                
                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: appData.imageName) { _, newValue in
            imageName = newValue
        }
        .onChange(of: isScanningOCR) { _, newValue in
            if !newValue {
                isTextFieldFocused = true
            }
        }
    }
}

// Updated OCR Camera Scanning View
struct OCRCameraView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @EnvironmentObject var appData: AppData
    let height: CGFloat

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let dataScanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced, // Balance speed and accuracy
            recognizesMultipleItems: false, // Focus on single item
            isHighFrameRateTrackingEnabled: true, // Smoother tracking
            isHighlightingEnabled: true
        )
        dataScanner.delegate = context.coordinator
        return dataScanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        do {
            if isScanning && !uiViewController.isScanning {
                try uiViewController.startScanning()
            } else if !isScanning && uiViewController.isScanning {
                uiViewController.stopScanning()
            }
        } catch {
            print("Scanning error: \(error.localizedDescription)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appData: appData, isScanning: $isScanning)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let appData: AppData
        private var isScanning: Binding<Bool>
        private var lastScanTime: Date = Date()
        private var stableText: String?
        private var stabilityCounter = 0
        private let stabilityThreshold = 2 // Require 2 consistent frames for stability

        init(appData: AppData, isScanning: Binding<Bool>) {
            self.appData = appData
            self.isScanning = isScanning
            super.init()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handleItem(item, force: true)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], didRemove removedItems: [RecognizedItem]) {
            if let firstItem = addedItems.first {
                handleItem(firstItem)
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem]) {
            if let firstItem = updatedItems.first {
                handleItem(firstItem)
            }
        }
        
        private func handleItem(_ item: RecognizedItem, force: Bool = false) {
            if case .text(let textItem) = item {
                let text = textItem.transcript
                
                guard OCRValidator.isValid(text) else { 
                    stabilityCounter = 0
                    return 
                }
                
                if force {
                    capture(text)
                    return
                }
                
                // Stability check: if the text matches the previous stable candidate, increment counter
                if text == stableText {
                    stabilityCounter += 1
                } else {
                    stableText = text
                    stabilityCounter = 1 // Reset counter for new candidate
                }
                
                // Only capture if we meet the stability threshold to avoid jittery/partial reads
                guard stabilityCounter >= stabilityThreshold else { return }
                
                // Debounce time check (optional secondary throttle)
                let now = Date()
                guard now.timeIntervalSince(lastScanTime) > 0.3 else { return }
                lastScanTime = now
                
                capture(text)
            }
        }
        
        private func capture(_ text: String) {
            DispatchQueue.main.async {
                // Haptic feedback
                self.appData.hapticService.playNotification(type: .success)
                
                // Update text field
                self.appData.imageName = text
                
                // Brief freeze for verification before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        self.isScanning.wrappedValue = false
                    }
                }
            }
        }
    }
}