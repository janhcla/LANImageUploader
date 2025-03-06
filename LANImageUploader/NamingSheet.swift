//
//  NamingSheet.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import VisionKit
import Vision // For text recognition
import UIKit // For UIImage and camera access
import Foundation // For optional logging

struct NamingSheet: View {
    @Binding var imageName: String
    @EnvironmentObject var appData: AppData
    var onSave: () -> Void
    var saveButtonLabel: String
    @Environment(\.dismiss) var dismiss
    @State private var isScanningOCR = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Name Your Image")
                .font(.headline)

            TextField("Image Name", text: $appData.imageName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($isTextFieldFocused)
                .overlay(alignment: .trailing) {
                    if !appData.imageName.isEmpty {
                        Button(action: { appData.imageName = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                                .padding(.trailing, 8)
                        }
                    } else {
                        Button(action: {
                            isTextFieldFocused = false // Dismiss keyboard
                            isScanningOCR.toggle()     // Toggle OCR view
                        }) {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.blue)
                                .padding(.trailing, 8)
                        }
                    }
                }

            if isScanningOCR {
                OCRCameraView(isScanning: $isScanningOCR, height: 300)
                    .frame(height: 300)
                    .cornerRadius(10)
            }

            Button(action: {
                imageName = appData.imageName // Sync back to binding
                onSave()
                dismiss()
            }) {
                Label(saveButtonLabel, systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .presentationDetents([.medium])
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: appData.imageName) { _, newValue in
            print("Text field updated to: \(newValue)")
            imageName = newValue // Sync binding
        }
        .onChange(of: isScanningOCR) { _, newValue in
            if !newValue {
                isTextFieldFocused = true // Refocus TextField when OCR hides
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
        print("DataScanner initialized with delegate: \(String(describing: dataScanner.delegate))")
        return dataScanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        do {
            if isScanning {
                try uiViewController.startScanning()
                print("Started scanning")
            } else {
                uiViewController.stopScanning()
                print("Stopped scanning")
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
            print("Coordinator initialized")
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let textItem) = item {
                let text = textItem.transcript
                print("Tapped on text: \(text)")
                DispatchQueue.main.async {
                    self.appData.imageName = text
                    print("Set appData.imageName to: \(text)")
                    self.isScanning.wrappedValue = false // Hide OCR view immediately
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], didRemove removedItems: [RecognizedItem]) {
            print("didAdd called with \(addedItems.count) items")
            for item in addedItems {
                if case .text(let textItem) = item {
                    let text = textItem.transcript
                    print("Recognized text (didAdd): \(text)")
                    DispatchQueue.main.async {
                        self.appData.imageName = text
                        print("Set appData.imageName to: \(text)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.isScanning.wrappedValue = false // Hide after 1 second
                        }
                    }
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem]) {
            print("didUpdate called with \(updatedItems.count) items")
            for item in updatedItems {
                if case .text(let textItem) = item {
                    let text = textItem.transcript
                    print("Recognized text (didUpdate): \(text)")
                    DispatchQueue.main.async {
                        self.appData.imageName = text
                        print("Set appData.imageName to: \(text)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.isScanning.wrappedValue = false // Hide after 1 second
                        }
                    }
                }
            }
        }
    }
}

//import SwiftUI
//
//struct NamingSheet: View {
//    @Binding var imageName: String
//    var onSave: () -> Void
//    var saveButtonText: String
//    @Environment(\.dismiss) var dismiss
//    @FocusState private var isTextFieldFocused: Bool
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Name Your Image")
//                .font(.headline)
//            HStack {
//                TextField("Image Name", text: $imageName)
//                    .textFieldStyle(.roundedBorder)
//                    .submitLabel(.done)
//                    .focused($isTextFieldFocused)
//                    .overlay(alignment: .trailing) {
//                        if !imageName.isEmpty {
//                            Button(action: { imageName = "" }) {
//                                Image(systemName: "xmark.circle.fill")
//                                    .foregroundStyle(.gray)
//                                    .padding(.trailing, 8)
//                            }
//                        }
//                    }
//            }
//            Button(action: {
//                onSave()
//                dismiss()
//            }) {
//                Label(saveButtonText, systemImage: "checkmark.circle")
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .foregroundStyle(.white)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//            }
//        }
//        .padding()
//        .presentationDetents([.medium])
//        .onAppear {
//            isTextFieldFocused = true
//        }
//    }
//}
