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

enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case scan = "Scan"

    var id: String { rawValue }
    var localizedTitleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

struct CameraZoomOption: Identifiable, Equatable {
    let factor: CGFloat
    let displayFactor: CGFloat

    var id: CGFloat { factor }

    var label: String {
        if displayFactor.rounded() == displayFactor {
            return "\(Int(displayFactor))x"
        }
        return String(format: "%.1fx", displayFactor)
    }

    static let standard = CameraZoomOption(factor: 1, displayFactor: 1)
}

struct PhotoCaptureFraming {
    static func normalizedVisibleRect(imageSize: CGSize, previewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              previewSize.width > 0, previewSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let imageAspect = imageSize.width / imageSize.height
        let previewAspect = previewSize.width / previewSize.height
        if imageAspect > previewAspect {
            let visibleWidth = previewAspect / imageAspect
            return CGRect(x: (1 - visibleWidth) / 2, y: 0, width: visibleWidth, height: 1)
        }

        let visibleHeight = imageAspect / previewAspect
        return CGRect(x: 0, y: (1 - visibleHeight) / 2, width: 1, height: visibleHeight)
    }

    static func image(_ image: UIImage, matchingAspectFillPreview previewSize: CGSize) -> UIImage {
        let upright = normalizedOrientationImage(image)
        guard let cgImage = upright.cgImage else { return image }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let visible = normalizedVisibleRect(imageSize: size, previewSize: previewSize)
        let crop = CGRect(
            x: visible.minX * size.width,
            y: visible.minY * size.height,
            width: visible.width * size.width,
            height: visible.height * size.height
        ).integral.intersection(CGRect(origin: .zero, size: size))
        guard !crop.isEmpty, let framed = cgImage.cropping(to: crop) else { return upright }
        return UIImage(cgImage: framed, scale: upright.scale, orientation: .up)
    }

    private static func normalizedOrientationImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

struct DocumentCaptureQuality {
    static func averageMovement(from first: DocumentCrop, to second: DocumentCrop) -> CGFloat {
        (hypot(first.topLeft.x - second.topLeft.x, first.topLeft.y - second.topLeft.y)
            + hypot(first.topRight.x - second.topRight.x, first.topRight.y - second.topRight.y)
            + hypot(first.bottomRight.x - second.bottomRight.x, first.bottomRight.y - second.bottomRight.y)
            + hypot(first.bottomLeft.x - second.bottomLeft.x, first.bottomLeft.y - second.bottomLeft.y)) / 4
    }

    static func isAcceptable(_ crop: DocumentCrop) -> Bool {
        func length(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let top = length(crop.topLeft, crop.topRight)
        let bottom = length(crop.bottomLeft, crop.bottomRight)
        let left = length(crop.topLeft, crop.bottomLeft)
        let right = length(crop.topRight, crop.bottomRight)
        let area = abs(
            crop.topLeft.x * crop.topRight.y - crop.topRight.x * crop.topLeft.y
                + crop.topRight.x * crop.bottomRight.y - crop.bottomRight.x * crop.topRight.y
                + crop.bottomRight.x * crop.bottomLeft.y - crop.bottomLeft.x * crop.bottomRight.y
                + crop.bottomLeft.x * crop.topLeft.y - crop.topLeft.x * crop.bottomLeft.y
        ) / 2

        guard max(top, bottom) > 0, max(left, right) > 0, area >= 0.18 else { return false }
        return abs(top - bottom) / max(top, bottom) < 0.18
            && abs(left - right) / max(left, right) < 0.18
    }

    static func smoothedDisplayCrop(
        from displayed: DocumentCrop?,
        toward latest: DocumentCrop,
        factor: CGFloat = 0.68
    ) -> DocumentCrop {
        guard let displayed else { return latest }
        let amount = min(max(factor, 0), 1)
        func interpolate(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
            CGPoint(
                x: start.x + (end.x - start.x) * amount,
                y: start.y + (end.y - start.y) * amount
            )
        }
        return DocumentCrop(
            topLeft: interpolate(displayed.topLeft, latest.topLeft),
            topRight: interpolate(displayed.topRight, latest.topRight),
            bottomRight: interpolate(displayed.bottomRight, latest.bottomRight),
            bottomLeft: interpolate(displayed.bottomLeft, latest.bottomLeft)
        )
    }
}

struct DocumentPreviewGeometry {
    static func points(
        for crop: DocumentCrop,
        imageSize: CGSize,
        previewBounds: CGRect
    ) -> DocumentCrop {
        let displayRect = aspectFillRect(imageSize: imageSize, in: previewBounds)
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: displayRect.minX + point.x * displayRect.width,
                y: displayRect.minY + point.y * displayRect.height
            )
        }
        return DocumentCrop(
            topLeft: map(crop.topLeft),
            topRight: map(crop.topRight),
            bottomRight: map(crop.bottomRight),
            bottomLeft: map(crop.bottomLeft)
        )
    }

    private static func aspectFillRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

struct ScannerCaptureView: View {
    let keptPhotoCount: Int
    let scannedPageCount: Int
    let onScanCapture: (UIImage, DocumentCrop) -> Void
    let onKeepPhoto: (UIImage) -> Void
    let onCountdownTick: () -> Void
    let onOpenGallery: (CameraCaptureMode) -> Void
    let onCancel: () -> Void

    @AppStorage(Constants.UserDefaults.scannerAutoCaptureEnabled) private var autoCapture = true
    @State private var mode: CameraCaptureMode
    @State private var captureRequest = UUID()
    @State private var guidance = "Point the camera at a document"
    @State private var documentFound = false
    @State private var countdown: Int?
    @State private var photoReviewImage: UIImage?
    @State private var zoomOptions: [CameraZoomOption] = [.standard]
    @State private var selectedZoomFactor: CGFloat = 1

    init(
        initialMode: CameraCaptureMode,
        keptPhotoCount: Int,
        scannedPageCount: Int,
        onScanCapture: @escaping (UIImage, DocumentCrop) -> Void,
        onKeepPhoto: @escaping (UIImage) -> Void,
        onCountdownTick: @escaping () -> Void,
        onOpenGallery: @escaping (CameraCaptureMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.keptPhotoCount = keptPhotoCount
        self.scannedPageCount = scannedPageCount
        self.onScanCapture = onScanCapture
        self.onKeepPhoto = onKeepPhoto
        self.onCountdownTick = onCountdownTick
        self.onOpenGallery = onOpenGallery
        self.onCancel = onCancel
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            ZStack {
                DocumentCameraPreview(
                    mode: mode,
                    autoCapture: $autoCapture,
                    captureRequest: captureRequest,
                    selectedZoomFactor: selectedZoomFactor,
                    onScanCapture: onScanCapture,
                    onPhotoCapture: { image in
                        photoReviewImage = image
                    },
                    onDetectionChanged: { message, found in
                        DispatchQueue.main.async {
                            guidance = message
                            documentFound = found
                        }
                    },
                    onCountdownChanged: { nextCountdown in
                        DispatchQueue.main.async {
                            if nextCountdown != nil, nextCountdown != countdown {
                                onCountdownTick()
                            }
                            countdown = nextCountdown
                        }
                    },
                    onZoomOptionsChanged: { options, currentFactor in
                        DispatchQueue.main.async {
                            zoomOptions = options.isEmpty ? [.standard] : options
                            selectedZoomFactor = currentFactor
                        }
                    }
                )
                .ignoresSafeArea()

                if let photoReviewImage {
                    photoReview(for: photoReviewImage, isLandscape: isLandscape)
                } else if isLandscape {
                    landscapeCaptureOverlay
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                } else {
                    portraitCaptureOverlay
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .background(.black)
            .accessibilityElement(children: .contain)
        }
        .onChange(of: mode) { _, _ in
            countdown = nil
            documentFound = false
            guidance = "Point the camera at a document"
        }
    }

    private var portraitCaptureOverlay: some View {
        VStack {
            scannerTopBar
            Spacer()
            if mode == .scan {
                guidanceBanner
            }
            captureBottomBar
        }
    }

    private var landscapeCaptureOverlay: some View {
        HStack(alignment: .center) {
            VStack {
                closeButton
                Spacer()
                galleryButton
            }
            Spacer()
            if mode == .scan {
                guidanceBanner
                    .frame(maxWidth: 300)
            }
            captureBottomBar
                .frame(width: 250)
        }
        .foregroundStyle(.white)
    }

    private var scannerTopBar: some View {
        HStack {
            closeButton

            Spacer()

            galleryButton
        }
        .foregroundStyle(.white)
    }

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.55), in: Circle())
        }
        .accessibilityLabel("Close scanner")
    }

    private var galleryButton: some View {
        Button(action: { onOpenGallery(mode) }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "photo.stack")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 44)
                    .background(.black.opacity(0.55), in: Capsule())
                if retainedItemCount > 0 {
                    Text("\(retainedItemCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.blue, in: Circle())
                        .offset(x: 4, y: -5)
                }
            }
        }
        .accessibilityLabel(galleryAccessibilityLabel)
    }

    private var guidanceBanner: some View {
        VStack(spacing: 12) {
            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(.yellow.opacity(0.88), in: Circle())
                    .accessibilityLabel("Auto capture in \(countdown)")
            }
            Text(guidance)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(documentFound ? Color.blue.opacity(0.82) : Color.black.opacity(0.65), in: Capsule())
                .accessibilityLabel(guidance)
        }
        .padding(.bottom, 18)
    }

    private var captureBottomBar: some View {
        VStack(spacing: 18) {
            Picker("Capture mode", selection: $mode) {
                ForEach(CameraCaptureMode.allCases) { mode in
                    Text(mode.localizedTitleKey).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("camera-mode-selector")

            zoomControls

            if mode == .scan {
                Toggle(isOn: $autoCapture) {
                    Label("Auto-capture", systemImage: autoCapture ? "sparkles.rectangle.stack.fill" : "hand.tap")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.55), in: Capsule())
                .accessibilityIdentifier("scanner-auto-capture-toggle")
            }

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
            .accessibilityLabel(mode == .scan ? "Scan page" : "Take photo")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 20)
    }

    private var zoomControls: some View {
        HStack(spacing: 10) {
            ForEach(zoomOptions) { option in
                Button {
                    selectedZoomFactor = option.factor
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedZoomFactor == option.factor ? .yellow : .white)
                        .frame(minWidth: 46, minHeight: 38)
                        .background(
                            selectedZoomFactor == option.factor ? .black.opacity(0.82) : .black.opacity(0.42),
                            in: Capsule()
                        )
                }
                .accessibilityLabel("Zoom \(option.label)")
                .accessibilityAddTraits(selectedZoomFactor == option.factor ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera-zoom-controls")
    }

    private func photoReview(for image: UIImage, isLandscape: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            Group {
                if isLandscape {
                    HStack(spacing: 16) {
                        VStack {
                            reviewIconButton(label: "Discard photo", systemName: "xmark") {
                                photoReviewImage = nil
                            }
                            Spacer()
                        }

                        GlassContainer(cornerRadius: 28) {
                            ZoomablePhotoReviewImage(image: image)
                        }
                        .accessibilityElement(children: .contain)

                        reviewActions(for: image)
                            .frame(width: 260)
                    }
                } else {
                    VStack(spacing: 16) {
                        HStack {
                            reviewIconButton(label: "Discard photo", systemName: "xmark") {
                                photoReviewImage = nil
                            }
                            Spacer()
                        }

                        GlassContainer(cornerRadius: 28) {
                            ZoomablePhotoReviewImage(image: image)
                        }
                        .accessibilityElement(children: .contain)

                        reviewActions(for: image)
                    }
                }
            }
            .padding(20)
        }
    }

    private func reviewActions(for image: UIImage) -> some View {
        GlassContainer(cornerRadius: 24) {
            HStack(spacing: 12) {
                Button {
                    photoReviewImage = nil
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Retake photo")

                Button {
                    onKeepPhoto(image)
                    photoReviewImage = nil
                } label: {
                    Label("Keep Photo", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.opacity(0.65), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Keep photo")
            }
        }
    }

    private func reviewIconButton(label: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.4), lineWidth: 1)
                }
        }
        .accessibilityLabel(label)
    }

    private var retainedItemCount: Int {
        mode == .photo ? keptPhotoCount : scannedPageCount
    }

    private var galleryAccessibilityLabel: String {
        if mode == .photo {
            return "Open gallery, \(keptPhotoCount) kept photos"
        }
        return "Open gallery, \(scannedPageCount) scanned pages"
    }
}

private struct ZoomablePhotoReviewImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var activeScale: CGFloat = 1
    @GestureState private var activeOffset: CGSize = .zero

    private var presentedScale: CGFloat {
        min(max(scale * activeScale, 1), 5)
    }

    private var presentedOffset: CGSize {
        guard presentedScale > 1 else { return .zero }
        return CGSize(width: offset.width + activeOffset.width, height: offset.height + activeOffset.height)
    }

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(presentedScale)
                .offset(presentedOffset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(magnifyGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.smooth(duration: 0.24)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Captured photo preview")
        .accessibilityHint("Pinch or double tap to zoom")
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($activeScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 1), 5)
                if scale == 1 {
                    offset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($activeOffset) { value, state, _ in
                if presentedScale > 1 {
                    state = value.translation
                }
            }
            .onEnded { value in
                guard scale > 1 else {
                    offset = .zero
                    return
                }
                offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
            }
    }
}

struct DocumentCameraPreview: UIViewControllerRepresentable {
    let mode: CameraCaptureMode
    @Binding var autoCapture: Bool
    let captureRequest: UUID
    let selectedZoomFactor: CGFloat
    let onScanCapture: (UIImage, DocumentCrop) -> Void
    let onPhotoCapture: (UIImage) -> Void
    let onDetectionChanged: (String, Bool) -> Void
    let onCountdownChanged: (Int?) -> Void
    let onZoomOptionsChanged: ([CameraZoomOption], CGFloat) -> Void

    func makeUIViewController(context: Context) -> DocumentCameraViewController {
        let controller = DocumentCameraViewController()
        controller.mode = mode
        controller.onScanCapture = onScanCapture
        controller.onPhotoCapture = onPhotoCapture
        controller.onDetectionChanged = onDetectionChanged
        controller.onCountdownChanged = onCountdownChanged
        controller.onZoomOptionsChanged = onZoomOptionsChanged
        controller.autoCaptureEnabled = autoCapture
        controller.start()
        return controller
    }

    func updateUIViewController(_ controller: DocumentCameraViewController, context: Context) {
        controller.mode = mode
        controller.autoCaptureEnabled = autoCapture
        controller.setZoomFactor(selectedZoomFactor)
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
    private let modeLock = NSLock()
    private var storedMode: CameraCaptureMode = .scan
    var mode: CameraCaptureMode {
        get {
            modeLock.lock()
            defer { modeLock.unlock() }
            return storedMode
        }
        set {
            modeLock.lock()
            let changed = storedMode != newValue
            storedMode = newValue
            modeLock.unlock()
            guard changed else { return }
            resetAutoCaptureState()
            boundaryLayer.removeAllAnimations()
            boundaryLayer.path = nil
            onDetectionChanged?(newValue == .scan ? "Point the camera at a document" : "", false)
        }
    }
    var onScanCapture: ((UIImage, DocumentCrop) -> Void)?
    var onPhotoCapture: ((UIImage) -> Void)?
    var onDetectionChanged: ((String, Bool) -> Void)?
    var onCountdownChanged: ((Int?) -> Void)?
    var onZoomOptionsChanged: (([CameraZoomOption], CGFloat) -> Void)?
    var autoCaptureEnabled = true {
        didSet {
            if !autoCaptureEnabled, oldValue != autoCaptureEnabled {
                stableSince = nil
                previousCrop = nil
                waitingForNextAutoPage = false
                updateCountdown(nil)
            }
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ImageDrop.scanner.session")
    private let detectionQueue = DispatchQueue(label: "ImageDrop.scanner.detection")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let boundaryLayer = CAShapeLayer()
    private let focusLayer = CAShapeLayer()
    private var activeDevice: AVCaptureDevice?
    private var latestCrop: DocumentCrop?
    private var displayedCrop: DocumentCrop?
    private var previousCrop: DocumentCrop?
    private var stableSince: Date?
    private var lastAutoCaptureAt = Date.distantPast
    private var lastDetectionAt = Date.distantPast
    private var pendingCaptureCrop: DocumentCrop = .fullFrame
    private var pendingCaptureMode: CameraCaptureMode = .scan
    private var captureInProgress = false
    private var waitingForNextAutoPage = false
    private var lastAutoCapturedCrop: DocumentCrop?
    private var visibleCountdown: Int?
    private var pendingPhotoPreviewSize: CGSize = .zero
    private var previewImageSize: CGSize = .zero
    private let autoCaptureHoldDuration: TimeInterval = 2.4

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
        focusLayer.fillColor = UIColor.clear.cgColor
        focusLayer.strokeColor = UIColor.systemYellow.cgColor
        focusLayer.lineWidth = 2
        focusLayer.opacity = 0
        view.layer.addSublayer(focusLayer)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExpose(at:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        boundaryLayer.frame = view.bounds
        focusLayer.frame = view.bounds
        updateCaptureOrientation()
        if let crop = displayedCrop {
            drawBoundary(crop, aligned: DocumentCaptureQuality.isAcceptable(crop))
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
            guard let device = self.preferredBackCamera(),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.activeDevice = device
            self.session.addInput(input)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.detectionQueue)
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            self.session.commitConfiguration()
            DispatchQueue.main.async {
                self.updateCaptureOrientation()
            }
            self.session.startRunning()
            let options = self.zoomOptions(for: device)
            let currentFactor = self.nearestZoomFactor(to: device.videoZoomFactor, options: options)
            DispatchQueue.main.async {
                self.onZoomOptionsChanged?(options, currentFactor)
            }
        }
    }

    private func updateCaptureOrientation() {
        let angle = currentVideoRotationAngle()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setVideoRotationAngle(angle, on: self.videoOutput.connection(with: .video))
            self.setVideoRotationAngle(angle, on: self.photoOutput.connection(with: .video))
        }
    }

    private func setVideoRotationAngle(_ angle: CGFloat, on connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func currentVideoRotationAngle() -> CGFloat {
        switch view.window?.windowScene?.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        case .portraitUpsideDown:
            return 270
        case .portrait, .unknown, nil:
            return 90
        @unknown default:
            return 90
        }
    }

    func capturePage(autoTriggered: Bool = false) {
        guard session.isRunning, !captureInProgress else { return }
        captureInProgress = true
        pendingCaptureMode = mode
        pendingCaptureCrop = mode == .scan ? (latestCrop ?? .fullFrame) : .fullFrame
        pendingPhotoPreviewSize = previewLayer.bounds.size
        if autoTriggered, mode == .scan {
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
                if self.pendingCaptureMode == .scan {
                    self.onScanCapture?(image, self.pendingCaptureCrop)
                } else {
                    self.onPhotoCapture?(PhotoCaptureFraming.image(
                        image,
                        matchingAspectFillPreview: self.pendingPhotoPreviewSize
                    ))
                }
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard mode == .scan else { return }
        let currentPreviewImageSize: CGSize?
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let rawSize = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
            currentPreviewImageSize = rawSize.height >= rawSize.width
                ? rawSize
                : CGSize(width: rawSize.height, height: rawSize.width)
        } else {
            currentPreviewImageSize = nil
        }
        guard Date().timeIntervalSince(lastDetectionAt) > 0.08 else { return }
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
            DispatchQueue.main.async { [weak self, currentPreviewImageSize] in
                if let currentPreviewImageSize {
                    self?.previewImageSize = currentPreviewImageSize
                }
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
        guard mode == .scan else { return }
        guard let crop = detectedCrop else {
            latestCrop = nil
            displayedCrop = nil
            boundaryLayer.removeAllAnimations()
            boundaryLayer.path = nil
            onDetectionChanged?("Point the camera at a document", false)
            resetAutoCaptureState()
            return
        }
        let acceptable = DocumentCaptureQuality.isAcceptable(crop)
        if autoCaptureEnabled, acceptable {
            updateStability(with: crop)
        } else {
            stableSince = nil
            previousCrop = nil
            updateCountdown(nil)
        }
        if waitingForNextAutoPage,
           let capturedCrop = lastAutoCapturedCrop,
           DocumentCaptureQuality.averageMovement(from: capturedCrop, to: crop) > 0.08 {
            waitingForNextAutoPage = false
        }
        latestCrop = crop
        let displayCrop = DocumentCaptureQuality.smoothedDisplayCrop(from: displayedCrop, toward: crop)
        displayedCrop = displayCrop
        drawBoundary(displayCrop, aligned: acceptable)
        let message: String
        if waitingForNextAutoPage {
            message = "Page saved - position the next page"
            updateCountdown(nil)
        } else if !acceptable {
            message = "Move closer and hold straight"
            stableSince = nil
            updateCountdown(nil)
        } else if autoCaptureEnabled, let stableSince {
            let elapsed = Date().timeIntervalSince(stableSince)
            let remaining = max(0, autoCaptureHoldDuration - elapsed)
            if remaining > 0 {
                let countdown = Int(ceil(remaining))
                updateCountdown(countdown)
                message = "Hold still - scanning in \(countdown)"
            } else {
                updateCountdown(nil)
                message = "Capturing page"
            }
        } else {
            updateCountdown(nil)
            message = "Ready to scan"
        }
        onDetectionChanged?(message, true)
        if autoCaptureEnabled,
           !waitingForNextAutoPage,
           acceptable,
           let stableSince,
           Date().timeIntervalSince(stableSince) >= autoCaptureHoldDuration,
           Date().timeIntervalSince(lastAutoCaptureAt) > 1.8 {
            lastAutoCaptureAt = Date()
            self.stableSince = nil
            updateCountdown(nil)
            capturePage(autoTriggered: true)
        }
    }

    private func updateStability(with crop: DocumentCrop) {
        defer { previousCrop = crop }
        guard let previousCrop else {
            stableSince = Date()
            return
        }
        let travel = DocumentCaptureQuality.averageMovement(from: previousCrop, to: crop)
        if travel > 0.025 {
            stableSince = Date()
        } else if stableSince == nil {
            stableSince = Date()
        }
    }

    private func updateCountdown(_ countdown: Int?) {
        guard countdown != visibleCountdown else { return }
        visibleCountdown = countdown
        onCountdownChanged?(countdown)
    }

    private func resetAutoCaptureState() {
        stableSince = nil
        previousCrop = nil
        waitingForNextAutoPage = false
        latestCrop = nil
        displayedCrop = nil
        updateCountdown(nil)
    }

    private func drawBoundary(_ crop: DocumentCrop, aligned: Bool) {
        let size = previewImageSize == .zero ? previewLayer.bounds.size : previewImageSize
        let points = DocumentPreviewGeometry.points(
            for: crop,
            imageSize: size,
            previewBounds: previewLayer.bounds
        )
        let path = UIBezierPath()
        path.move(to: points.topLeft)
        path.addLine(to: points.topRight)
        path.addLine(to: points.bottomRight)
        path.addLine(to: points.bottomLeft)
        path.close()
        let previousPath = boundaryLayer.path
        boundaryLayer.strokeColor = (aligned ? UIColor.systemYellow : UIColor.white).cgColor
        boundaryLayer.path = path.cgPath
        if let previousPath {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = previousPath
            animation.toValue = path.cgPath
            animation.duration = 0.07
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            boundaryLayer.add(animation, forKey: "document-boundary-transition")
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            guard abs(clamped - device.videoZoomFactor) > 0.001 else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    @objc private func focusAndExpose(at gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: view)
        guard view.bounds.contains(location) else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        displayFocusReticle(at: location)
        sessionQueue.async { [weak self] in
            guard let device = self?.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    private func displayFocusReticle(at location: CGPoint) {
        let size: CGFloat = 68
        let rect = CGRect(x: location.x - size / 2, y: location.y - size / 2, width: size, height: size)
        focusLayer.removeAllAnimations()
        focusLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: 8).cgPath
        focusLayer.opacity = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.55
        fade.duration = 0.3
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        focusLayer.add(fade, forKey: "focus-fade")
    }

    private func preferredBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        return types.lazy.compactMap {
            AVCaptureDevice.default($0, for: .video, position: .back)
        }.first
    }

    private func zoomOptions(for device: AVCaptureDevice) -> [CameraZoomOption] {
        let multiplier = device.displayVideoZoomFactorMultiplier
        let desiredDisplayFactors: [CGFloat] = [0.5, 1, 2, 3]
        var factors = [device.minAvailableVideoZoomFactor, 1]
        factors.append(contentsOf: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) })
        factors.append(contentsOf: desiredDisplayFactors.map { $0 / multiplier })
        let available = factors.filter {
            $0 >= device.minAvailableVideoZoomFactor && $0 <= device.maxAvailableVideoZoomFactor
        }.sorted()
        var options: [CameraZoomOption] = []
        for factor in available where !options.contains(where: { abs($0.factor - factor) < 0.01 }) {
            options.append(CameraZoomOption(factor: factor, displayFactor: factor * multiplier))
        }
        return options.isEmpty ? [.standard] : options
    }

    private func nearestZoomFactor(to factor: CGFloat, options: [CameraZoomOption]) -> CGFloat {
        options.min(by: { abs($0.factor - factor) < abs($1.factor - factor) })?.factor ?? factor
    }
}
