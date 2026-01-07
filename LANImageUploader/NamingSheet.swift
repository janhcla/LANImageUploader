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
        let dataScanner = DataScannerViewController(recognizedDataTypes: [.text()], isHighlightingEnabled: true)
        dataScanner.delegate = context.coordinator
        return dataScanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        do {
            if isScanning {
                try uiViewController.startScanning()
            } else {
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

        init(appData: AppData, isScanning: Binding<Bool>) {
            self.appData = appData
            self.isScanning = isScanning
            super.init()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let textItem) = item {
                let text = textItem.transcript
                DispatchQueue.main.async {
                    self.appData.imageName = text
                    self.appData.hapticService.playNotification(type: .success)
                    withAnimation {
                        self.isScanning.wrappedValue = false
                    }
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], didRemove removedItems: [RecognizedItem]) {
            handleItems(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem]) {
            handleItems(updatedItems)
        }
        
        private func handleItems(_ items: [RecognizedItem]) {
            for item in items {
                if case .text(let textItem) = item {
                    let text = textItem.transcript
                    DispatchQueue.main.async {
                        self.appData.imageName = text
                        // We don't auto-dismiss here to allow user to pick another one if it's wrong
                        // But we could play a very subtle haptic
                    }
                }
            }
        }
    }
}