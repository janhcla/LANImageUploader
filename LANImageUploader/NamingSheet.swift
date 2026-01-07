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
    @State private var isHighlighted = false

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
                        .scaleEffect(isHighlighted ? 1.05 : 1.0) // Scale effect for feedback
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isHighlighted)
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
                        OCRCameraView(isScanning: $isScanningOCR, height: 260, onCapture: {
                            // Trigger highlight animation
                            isHighlighted = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isHighlighted = false
                            }
                        })
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
    var onCapture: (() -> Void)? = nil // Callback for capture event
    @State private var isFrozen = false // State to control freezing

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let dataScanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        dataScanner.delegate = context.coordinator
        return dataScanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        do {
            // Only start scanning if explicitly requested AND not frozen
            if isScanning && !uiViewController.isScanning && !context.coordinator.isFrozen {
                try uiViewController.startScanning()
            } 
            
            // Explicitly stop scanning if frozen or if isScanning became false
            if !isScanning || context.coordinator.isFrozen {
                uiViewController.stopScanning()
            }
        } catch {
            print("Scanning error: \(error.localizedDescription)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appData: appData, isScanning: $isScanning, onCapture: onCapture)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let appData: AppData
        private var isScanning: Binding<Bool>
        private var lastScanTime: Date = Date()
        private var stableText: String?
        private var stabilityCounter = 0
        private let stabilityThreshold = 2
        var isFrozen = false
        var onCapture: (() -> Void)?

        init(appData: AppData, isScanning: Binding<Bool>, onCapture: (() -> Void)?) {
            self.appData = appData
            self.isScanning = isScanning
            self.onCapture = onCapture
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
                
                if text == stableText {
                    stabilityCounter += 1
                } else {
                    stableText = text
                    stabilityCounter = 1
                }
                
                guard stabilityCounter >= stabilityThreshold else { return }
                
                let now = Date()
                guard now.timeIntervalSince(lastScanTime) > 0.3 else { return }
                lastScanTime = now
                
                capture(text)
            }
        }
        
        private func capture(_ text: String) {
            guard !isFrozen else { return }
            isFrozen = true
            
            DispatchQueue.main.async {
                // Play a more prominent haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
                
                self.appData.imageName = text
                self.onCapture?() 
                
                // Trigger the freeze by updating the view (updateUIViewController will see isFrozen=true)
                // We force a UI update implicitly by changing state in the parent if needed, 
                // but here our coordinator state drives the logic.
                
                // Ensure the freeze duration is respected before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation {
                        self.isScanning.wrappedValue = false
                        // Reset frozen state after dismissal animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isFrozen = false
                        }
                    }
                }
            }
        }
    }
}
