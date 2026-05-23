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
    @AppStorage(Constants.UserDefaults.ocrMode) private var ocrModeRawValue: String = OCRMode.full.rawValue
    var title: String = "Name Your Image"
    var placeholder: String = "Enter name..."
    var onSave: () -> Void
    var saveButtonLabel: String
    @Environment(\.dismiss) var dismiss
    @State private var isScanningOCR = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isHighlighted = false
    @State private var showCPRDetected = false

    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 24) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top)

                GlassContainer(cornerRadius: 16) {
                    TextField(placeholder, text: $imageName)
                        .font(.body)
                        .submitLabel(.done)
                        .focused($isTextFieldFocused)
                        .scaleEffect(isHighlighted ? 1.05 : 1.0) // Scale effect for feedback
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isHighlighted)
                        .overlay(alignment: .trailing) {
                            HStack {
                                if !imageName.isEmpty {
                                    Button(action: { 
                                        appData.hapticService.playSelection()
                                        imageName = ""
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
                        OCRCameraView(
                            isScanning: $isScanningOCR,
                            ocrMode: OCRMode(rawValue: ocrModeRawValue) ?? .full,
                            height: 260,
                            onDetect: {
                                showCPRDetected = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                    showCPRDetected = false
                                }
                            },
                            onCapture: {
                            // Trigger highlight animation
                            isHighlighted = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isHighlighted = false
                            }
                        }
                        )
                        .frame(height: 260)
                    }
                    .overlay(alignment: .topLeading) {
                        if showCPRDetected {
                            Text("CPR detected")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.9))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCPRDetected)
                    .transition(.scale.combined(with: .opacity))
                }

                Button(action: {
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
    let ocrMode: OCRMode
    let height: CGFloat
    var onDetect: (() -> Void)? = nil
    var onCapture: (() -> Void)? = nil // Callback for capture event
    @State private var isFrozen = false // State to control freezing

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let dataScanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
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
        Coordinator(
            appData: appData,
            isScanning: $isScanning,
            ocrMode: ocrMode,
            onDetect: onDetect,
            onCapture: onCapture
        )
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let appData: AppData
        private var isScanning: Binding<Bool>
        private let ocrMode: OCRMode
        var isFrozen = false
        var onDetect: (() -> Void)?
        var onCapture: (() -> Void)?

        init(
            appData: AppData,
            isScanning: Binding<Bool>,
            ocrMode: OCRMode,
            onDetect: (() -> Void)?,
            onCapture: (() -> Void)?
        ) {
            self.appData = appData
            self.isScanning = isScanning
            self.ocrMode = ocrMode
            self.onDetect = onDetect
            self.onCapture = onCapture
            super.init()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handleItems([item], force: true)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handleItems(addedItems)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handleItems(updatedItems)
        }

        private func handleItems(_ items: [RecognizedItem], force: Bool = false) {
            guard force || ocrMode == .cpr else { return }
            
            for item in items {
                guard !isFrozen else { return }
                guard case .text(let textItem) = item else { continue }
                
                let text = textItem.transcript
                guard let sanitized = OCRValidator.sanitizedText(from: text, mode: ocrMode) else { continue }
                
                if force {
                    capture(sanitized)
                    return
                }

                DispatchQueue.main.async {
                    self.onDetect?()
                }
                capture(sanitized)
                return
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
