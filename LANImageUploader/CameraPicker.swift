//
//  CameraPicker.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import UIKit
@preconcurrency import AVFoundation
import Vision

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Wrapper to ensure the picker covers the entire screen with black background
struct CameraPickerWrapper: View {
    @Binding var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            CameraPicker(image: $image)
                .ignoresSafeArea(.all)
        }
    }
}

struct ScannerCaptureView: View {
    let capturedPageCount: Int
    let onCapture: (UIImage, DocumentCrop) -> Void
    let onOpenGallery: () -> Void
    let onCancel: () -> Void

    @AppStorage(Constants.UserDefaults.scannerAutoCaptureEnabled) private var autoCapture = true
    @State private var captureRequest = UUID()
    @State private var guidance = "Point the camera at a document"
    @State private var documentFound = false

    var body: some View {
        ZStack {
            DocumentCameraPreview(
                autoCapture: $autoCapture,
                captureRequest: captureRequest,
                onCapture: onCapture,
                onDetectionChanged: { message, found in
                    guidance = message
                    documentFound = found
                }
            )
            .ignoresSafeArea()

            VStack {
                scannerTopBar
                Spacer()
                guidanceBanner
                scannerBottomBar
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.black)
        .accessibilityElement(children: .contain)
    }

    private var scannerTopBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Close scanner")

            Spacer()

            Button(action: onOpenGallery) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "photo.stack")
                        .font(.title3.weight(.semibold))
                        .frame(width: 52, height: 44)
                        .background(.black.opacity(0.55), in: Capsule())
                    if capturedPageCount > 0 {
                        Text("\(capturedPageCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.blue, in: Circle())
                            .offset(x: 4, y: -5)
                    }
                }
            }
            .accessibilityLabel("Open gallery, \(capturedPageCount) scanned pages")
        }
        .foregroundStyle(.white)
    }

    private var guidanceBanner: some View {
        Text(guidance)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(documentFound ? Color.blue.opacity(0.82) : Color.black.opacity(0.65), in: Capsule())
            .accessibilityLabel(guidance)
            .padding(.bottom, 18)
    }

    private var scannerBottomBar: some View {
        VStack(spacing: 18) {
            Toggle(isOn: $autoCapture) {
                Label("Auto-capture", systemImage: autoCapture ? "sparkles.rectangle.stack.fill" : "hand.tap")
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityIdentifier("scanner-auto-capture-toggle")

            Button {
                captureRequest = UUID()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Circle().stroke(.white.opacity(0.7), lineWidth: 5).padding(-7)
                    }
            }
            .accessibilityLabel("Scan page")
        }
        .padding(.bottom, 20)
    }
}

struct DocumentCameraPreview: UIViewControllerRepresentable {
    @Binding var autoCapture: Bool
    let captureRequest: UUID
    let onCapture: (UIImage, DocumentCrop) -> Void
    let onDetectionChanged: (String, Bool) -> Void

    func makeUIViewController(context: Context) -> DocumentCameraViewController {
        let controller = DocumentCameraViewController()
        controller.onCapture = onCapture
        controller.onDetectionChanged = onDetectionChanged
        controller.autoCaptureEnabled = autoCapture
        controller.start()
        return controller
    }

    func updateUIViewController(_ controller: DocumentCameraViewController, context: Context) {
        controller.autoCaptureEnabled = autoCapture
        if context.coordinator.lastCaptureRequest != captureRequest {
            context.coordinator.lastCaptureRequest = captureRequest
            controller.capturePage()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(captureRequest: captureRequest)
    }

    final class Coordinator {
        var lastCaptureRequest: UUID
        init(captureRequest: UUID) {
            self.lastCaptureRequest = captureRequest
        }
    }
}

final class DocumentCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onCapture: ((UIImage, DocumentCrop) -> Void)?
    var onDetectionChanged: ((String, Bool) -> Void)?
    var autoCaptureEnabled = true

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ImageDrop.scanner.session")
    private let detectionQueue = DispatchQueue(label: "ImageDrop.scanner.detection")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let boundaryLayer = CAShapeLayer()
    private var latestCrop: DocumentCrop?
    private var previousCrop: DocumentCrop?
    private var stableSince: Date?
    private var lastAutoCaptureAt = Date.distantPast
    private var lastDetectionAt = Date.distantPast
    private var pendingCaptureCrop: DocumentCrop = .fullFrame
    private var captureInProgress = false
    private var waitingForNextAutoPage = false
    private var lastAutoCapturedCrop: DocumentCrop?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        boundaryLayer.fillColor = UIColor.clear.cgColor
        boundaryLayer.lineWidth = 3
        boundaryLayer.lineJoin = .round
        view.layer.addSublayer(boundaryLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        boundaryLayer.frame = view.bounds
        if let crop = latestCrop {
            drawBoundary(crop, aligned: documentAppearsStraight(crop))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    self?.onDetectionChanged?("Camera permission is required", false)
                }
                return
            }
            self?.configureAndStartSession()
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.detectionQueue)
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
            self.photoOutput.connection(with: .video)?.videoRotationAngle = 90
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func capturePage(autoTriggered: Bool = false) {
        guard session.isRunning, !captureInProgress else { return }
        captureInProgress = true
        pendingCaptureCrop = latestCrop ?? .fullFrame
        if autoTriggered {
            waitingForNextAutoPage = true
            lastAutoCapturedCrop = pendingCaptureCrop
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = photoOutput.supportedFlashModes.contains(.auto) ? .auto : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = error == nil
            ? photo.fileDataRepresentation().flatMap(UIImage.init(data:))
            : nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.captureInProgress = false
            if let image {
                self.onCapture?(image, self.pendingCaptureCrop)
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard Date().timeIntervalSince(lastDetectionAt) > 0.16 else { return }
        lastDetectionAt = Date()
        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let observation = (request.results as? [VNRectangleObservation])?.first
            let crop = observation.map {
                DocumentCrop(
                    topLeft: CGPoint(x: $0.topLeft.x, y: 1 - $0.topLeft.y),
                    topRight: CGPoint(x: $0.topRight.x, y: 1 - $0.topRight.y),
                    bottomRight: CGPoint(x: $0.bottomRight.x, y: 1 - $0.bottomRight.y),
                    bottomLeft: CGPoint(x: $0.bottomLeft.x, y: 1 - $0.bottomLeft.y)
                ).clamped()
            }
            DispatchQueue.main.async { [weak self] in
                self?.handleDetectedCrop(crop)
            }
        }
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumSize = 0.18
        request.quadratureTolerance = 35
        try? VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up).perform([request])
    }

    private func handleDetectedCrop(_ detectedCrop: DocumentCrop?) {
        guard let crop = detectedCrop else {
            latestCrop = nil
            boundaryLayer.path = nil
            onDetectionChanged?("Point the camera at a document", false)
            stableSince = nil
            previousCrop = nil
            waitingForNextAutoPage = false
            return
        }
        let aligned = documentAppearsStraight(crop)
        updateStability(with: crop)
        if waitingForNextAutoPage,
           let capturedCrop = lastAutoCapturedCrop,
           averageMovement(from: capturedCrop, to: crop) > 0.08 {
            waitingForNextAutoPage = false
        }
        latestCrop = crop
        drawBoundary(crop, aligned: aligned)
        let message: String
        if waitingForNextAutoPage {
            message = "Page saved - position the next page"
        } else {
            message = aligned ? "Ready to scan" : "Hold straight"
        }
        onDetectionChanged?(message, true)
        if autoCaptureEnabled,
           !waitingForNextAutoPage,
           aligned,
           let stableSince,
           Date().timeIntervalSince(stableSince) > 0.8,
           Date().timeIntervalSince(lastAutoCaptureAt) > 1.8 {
            lastAutoCaptureAt = Date()
            self.stableSince = nil
            capturePage(autoTriggered: true)
        }
    }

    private func updateStability(with crop: DocumentCrop) {
        defer { previousCrop = crop }
        guard let previousCrop else {
            stableSince = Date()
            return
        }
        let travel = averageMovement(from: previousCrop, to: crop)
        if travel > 0.025 {
            stableSince = Date()
        } else if stableSince == nil {
            stableSince = Date()
        }
    }

    private func averageMovement(from first: DocumentCrop, to second: DocumentCrop) -> CGFloat {
        zip(first.points, second.points)
            .map { hypot($0.x - $1.x, $0.y - $1.y) }
            .reduce(0, +) / 4
    }

    private func documentAppearsStraight(_ crop: DocumentCrop) -> Bool {
        func length(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let top = length(crop.topLeft, crop.topRight)
        let bottom = length(crop.bottomLeft, crop.bottomRight)
        let left = length(crop.topLeft, crop.bottomLeft)
        let right = length(crop.topRight, crop.bottomRight)
        guard max(top, bottom) > 0, max(left, right) > 0 else { return false }
        return abs(top - bottom) / max(top, bottom) < 0.22
            && abs(left - right) / max(left, right) < 0.22
    }

    private func drawBoundary(_ crop: DocumentCrop, aligned: Bool) {
        let points = crop.points.map {
            previewLayer.layerPointConverted(
                fromCaptureDevicePoint: CGPoint(x: $0.x, y: $0.y)
            )
        }
        let path = UIBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.close()
        boundaryLayer.strokeColor = (aligned ? UIColor.systemYellow : UIColor.white).cgColor
        boundaryLayer.path = path.cgPath
    }
}
