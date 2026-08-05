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
#if DEBUG
import OSLog
#endif

enum ScannerCapturePolicy {
    static let automaticallyConfiguresApplicationAudioSession = false
    static let includesAudioInput = false
}

enum DocumentCaptureOrientation {
    static func visionOrientation(forVideoRotationAngle angle: CGFloat) -> CGImagePropertyOrientation {
        switch normalizedAngle(angle) {
        case 0: return .up
        case 90: return .right
        case 180: return .down
        case 270: return .left
        default: return .up
        }
    }

    static func orientedSize(_ size: CGSize, orientation: CGImagePropertyOrientation) -> CGSize {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }

    private static func normalizedAngle(_ angle: CGFloat) -> Int {
        let rounded = Int(angle.rounded()) % 360
        return rounded >= 0 ? rounded : rounded + 360
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.cameraCaptureMode = .photo
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
    static let preferredDisplayFactors: [CGFloat] = [0.5, 1, 2, 3, 4]
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

    static func visibleCrop(imageSize: CGSize, previewSize: CGSize) -> DocumentCrop {
        let rect = normalizedVisibleRect(imageSize: imageSize, previewSize: previewSize)
        return DocumentCrop(
            topLeft: CGPoint(x: rect.minX, y: rect.minY),
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        )
    }

    static func crop(_ crop: DocumentCrop, isVisibleIn visibleRect: CGRect, epsilon: CGFloat = 0.002) -> Bool {
        let expanded = visibleRect.insetBy(dx: -epsilon, dy: -epsilon)
        return crop.points.allSatisfy(expanded.contains)
    }

    static func normalizedOrientationImage(_ image: UIImage) -> UIImage {
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

    static func hasMovedToNextPage(
        from capturedCrop: DocumentCrop?,
        to currentCrop: DocumentCrop,
        threshold: CGFloat = 0.08
    ) -> Bool {
        guard let capturedCrop else { return false }
        return averageMovement(from: capturedCrop, to: currentCrop) > threshold
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
    let onScanCapture: (Data, DocumentCrop?, @escaping (Bool) -> Void) -> Void
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
    @State private var cameraPermissionDenied = false

    init(
        initialMode: CameraCaptureMode,
        keptPhotoCount: Int,
        scannedPageCount: Int,
        onScanCapture: @escaping (Data, DocumentCrop?, @escaping (Bool) -> Void) -> Void,
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
                    },
                    onCameraPermissionDenied: {
                        DispatchQueue.main.async {
                            cameraPermissionDenied = true
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
            cameraPermissionDenied = false
        }
    }

    private var portraitCaptureOverlay: some View {
        VStack {
            scannerTopBar
            Spacer()
            if mode == .scan {
                guidanceBanner
            }
            captureBottomBar(isLandscape: false)
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
            captureBottomBar(isLandscape: true)
                .frame(width: 260)
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
            if cameraPermissionDenied {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .accessibilityHint("Opens iPhone Settings so camera access can be enabled")
            }
        }
        .padding(.bottom, 18)
    }

    private func captureBottomBar(isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 12 : 18) {
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
        .padding(.horizontal, isLandscape ? 10 : 12)
        .padding(.vertical, isLandscape ? 12 : 14)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, isLandscape ? 0 : 20)
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

                        reviewActions(for: image, isLandscape: true)
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

                        reviewActions(for: image, isLandscape: false)
                    }
                }
            }
            .padding(20)
        }
    }

    private func reviewActions(for image: UIImage, isLandscape: Bool) -> some View {
        GlassContainer(cornerRadius: 24) {
            let layout = isLandscape ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
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
            .padding(isLandscape ? 12 : 0)
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
    let onScanCapture: (Data, DocumentCrop?, @escaping (Bool) -> Void) -> Void
    let onPhotoCapture: (UIImage) -> Void
    let onDetectionChanged: (String, Bool) -> Void
    let onCountdownChanged: (Int?) -> Void
    let onZoomOptionsChanged: ([CameraZoomOption], CGFloat) -> Void
    let onCameraPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> DocumentCameraViewController {
        let controller = DocumentCameraViewController()
        controller.mode = mode
        controller.onScanCapture = onScanCapture
        controller.onPhotoCapture = onPhotoCapture
        controller.onDetectionChanged = onDetectionChanged
        controller.onCountdownChanged = onCountdownChanged
        controller.onZoomOptionsChanged = onZoomOptionsChanged
        controller.onCameraPermissionDenied = onCameraPermissionDenied
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
    private struct DetectedCrop {
        let crop: DocumentCrop
        let orientedBufferSize: CGSize
        let orientationGeneration: Int
    }

#if DEBUG
    private static let audioLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LensBridge",
        category: "CameraAudioSession"
    )
#endif

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
            resetVisionSequence()
            boundaryLayer.removeAllAnimations()
            boundaryLayer.path = nil
            onDetectionChanged?(newValue == .scan ? "Point the camera at a document" : "", false)
        }
    }
    var onScanCapture: ((Data, DocumentCrop?, @escaping (Bool) -> Void) -> Void)?
    var onPhotoCapture: ((UIImage) -> Void)?
    var onDetectionChanged: ((String, Bool) -> Void)?
    var onCountdownChanged: ((Int?) -> Void)?
    var onZoomOptionsChanged: (([CameraZoomOption], CGFloat) -> Void)?
    var onCameraPermissionDenied: (() -> Void)?
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
    private let sessionQueue = DispatchQueue(label: "LensBridge.scanner.session")
    private let detectionQueue = DispatchQueue(label: "LensBridge.scanner.detection")
    // VNSequenceRequestHandler keeps temporal Vision context. It is accessed
    // only from detectionQueue so frame order and handler state stay coherent.
    private var visionSequenceHandler = VNSequenceRequestHandler()
    private let photoProcessingQueue = DispatchQueue(
        label: "LensBridge.scanner.photo-processing",
        qos: .userInitiated
    )
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let boundaryLayer = CAShapeLayer()
    private let focusLayer = CAShapeLayer()
    private var activeDevice: AVCaptureDevice?
    private var latestDetection: DetectedCrop?
    private var displayedCrop: DocumentCrop?
    private var previousCrop: DocumentCrop?
    private var stableSince: Date?
    private var lastAutoCaptureAt = Date.distantPast
    private var lastDetectionAt = Date.distantPast
    private var pendingCaptureDetection: DetectedCrop?
    private var pendingCaptureMode: CameraCaptureMode = .scan
    private var pendingAutoCapture = false
    private var captureInProgress = false
    private var waitingForNextAutoPage = false
    private var lastAutoCapturedCrop: DocumentCrop?
    private var visibleCountdown: Int?
    private var pendingPhotoPreviewSize: CGSize = .zero
    private var previewImageSize: CGSize = .zero
    private let orientationLock = NSLock()
    private var visionOrientation: CGImagePropertyOrientation = .right
    private var orientationGeneration = 0
    private var appliedVideoRotationAngle: CGFloat = -1
    // Session state is only read and written on sessionQueue. Keeping this
    // separate from view visibility prevents an interruption notification from
    // restarting the camera after the scanner has already been dismissed.
    private var wantsSessionRunning = false
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruption(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruptionEnded(_:)),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )
#if DEBUG
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
#endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
            guard let self else { return }
            self.wantsSessionRunning = false
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.resetVisionSequence()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.captureInProgress = false
                self.pendingCaptureDetection = nil
                self.pendingAutoCapture = false
                self.pendingPhotoPreviewSize = .zero
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.sync { [weak self] in
            self?.wantsSessionRunning = true
        }
        start()
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    self?.onDetectionChanged?("Camera permission is required", false)
                    self?.onCameraPermissionDenied?()
                }
                return
            }
            self?.configureAndStartSession()
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.wantsSessionRunning, !self.session.isRunning else { return }
            self.session.automaticallyConfiguresApplicationAudioSession =
                ScannerCapturePolicy.automaticallyConfiguresApplicationAudioSession

            let hasVideoInput = self.session.inputs.contains { input in
                (input as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
            }
            let hasPhotoOutput = self.session.outputs.contains { $0 === self.photoOutput }
            let hasVideoOutput = self.session.outputs.contains { $0 === self.videoOutput }

            if !hasVideoInput || !hasPhotoOutput || !hasVideoOutput {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                if !hasVideoInput {
                    guard let device = self.preferredBackCamera(),
                          device.hasMediaType(.video),
                          let input = try? AVCaptureDeviceInput(device: device),
                          self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        return
                    }
                    self.activeDevice = device
                    self.session.addInput(input)
                } else if let input = self.session.inputs
                    .compactMap({ $0 as? AVCaptureDeviceInput })
                    .first(where: { $0.device.hasMediaType(.video) }) {
                    self.activeDevice = input.device
                }

                if !hasPhotoOutput, self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                if !hasVideoOutput, self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                self.session.commitConfiguration()
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.detectionQueue)
            DispatchQueue.main.async {
                self.updateCaptureOrientation()
            }
            // A dismissal can be queued while session configuration is in
            // progress. Do not start a session after the view has opted out.
            guard self.wantsSessionRunning else {
                self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
                return
            }
            self.session.startRunning()
            guard self.wantsSessionRunning else {
                self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                return
            }
#if DEBUG
            assert(!self.session.inputs.contains { $0.ports.contains { $0.mediaType == .audio } })
#endif
            guard let device = self.activeDevice else { return }
            let options = self.zoomOptions(for: device)
            let currentFactor = self.nearestZoomFactor(to: device.videoZoomFactor, options: options)
            DispatchQueue.main.async {
                self.onZoomOptionsChanged?(options, currentFactor)
            }
        }
    }

    @objc private func handleSessionInterruption(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateCountdown(nil)
            self.onDetectionChanged?("Camera temporarily unavailable", false)
        }
    }

    @objc private func handleSessionInterruptionEnded(_ notification: Notification) {
        configureAndStartSession()
    }

    @objc private func handleSessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
        sessionQueue.async { [weak self] in
            guard let self, self.wantsSessionRunning else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateCountdown(nil)
                self.onDetectionChanged?("Camera error - trying to reconnect", false)
            }
            if error?.code == AVError.mediaServicesWereReset.rawValue || !self.session.isRunning {
                self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
                self.resetVisionSequence()
                self.configureAndStartSessionIfNeeded()
            }
        }
    }

    private func configureAndStartSessionIfNeeded() {
        guard wantsSessionRunning, !session.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.configureAndStartSession()
        }
    }

#if DEBUG
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        Self.audioLogger.debug("Observed audio interruption type: \(rawType.map(String.init) ?? "unknown", privacy: .private)")
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        Self.audioLogger.debug("Observed audio route change reason: \(rawReason.map(String.init) ?? "unknown", privacy: .private)")
    }
#endif

    private func updateCaptureOrientation() {
        let angle = currentVideoRotationAngle()
        if angle != appliedVideoRotationAngle {
            appliedVideoRotationAngle = angle
            orientationLock.withLock {
                visionOrientation = DocumentCaptureOrientation.visionOrientation(forVideoRotationAngle: angle)
                orientationGeneration += 1
            }
            resetVisionSequence()
            latestDetection = nil
            displayedCrop = nil
            previewImageSize = .zero
            boundaryLayer.path = nil
            resetAutoCaptureState()
        }
        setVideoRotationAngle(angle, on: previewLayer.connection)
        sessionQueue.async { [weak self] in
            guard let self else { return }
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
            return 180
        case .landscapeRight:
            return 0
        case .portraitUpsideDown:
            return 270
        case .portrait, .unknown, nil:
            return 90
        @unknown default:
            return 90
        }
    }

    func capturePage(autoTriggered: Bool = false) {
        guard !captureInProgress else { return }
        captureInProgress = true
        pendingCaptureMode = mode
        pendingAutoCapture = autoTriggered && mode == .scan
        let currentGeneration = orientationLock.withLock { orientationGeneration }
        pendingCaptureDetection = mode == .scan
            ? latestDetection.flatMap { detection in
                guard detection.orientationGeneration == currentGeneration else { return nil }
                return DetectedCrop(
                    crop: displayedCrop ?? detection.crop,
                    orientedBufferSize: detection.orientedBufferSize,
                    orientationGeneration: detection.orientationGeneration
                )
            }
            : nil
        pendingPhotoPreviewSize = previewLayer.bounds.size
        let settings = AVCapturePhotoSettings()
        settings.flashMode = photoOutput.supportedFlashModes.contains(.auto) ? .auto : .off
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                DispatchQueue.main.async {
                    self?.captureInProgress = false
                    self?.pendingAutoCapture = false
                }
                return
            }
            // The session queue also applies zoom changes, so queuing capture here
            // guarantees that the saved photo uses the zoom shown as selected.
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let data else {
                self.captureInProgress = false
                return
            }
            let captureMode = self.pendingCaptureMode
            let detection = self.pendingCaptureDetection
            let previewSize = self.pendingPhotoPreviewSize
            self.photoProcessingQueue.async { [weak self] in
                guard let self else { return }
                if captureMode == .scan {
                    guard let photoSize = CIImage(
                        data: data,
                        options: [.applyOrientationProperty: true]
                    )?.extent.size else {
                        DispatchQueue.main.async {
                            self.captureInProgress = false
                            self.pendingAutoCapture = false
                        }
                        return
                    }
                    let visibleRect = PhotoCaptureFraming.normalizedVisibleRect(
                        imageSize: photoSize,
                        previewSize: previewSize
                    )
                    let detectedCrop = detection?
                        .crop
                        .mapped(
                            fromAspectFillImageSize: detection?.orientedBufferSize ?? .zero,
                            toImageSize: photoSize
                        )
                        .flatMap { $0.isValidForPerspectiveCorrection() ? $0.clamped() : nil }
                    let crop = detectedCrop.flatMap {
                        PhotoCaptureFraming.crop($0, isVisibleIn: visibleRect) ? $0 : nil
                    } ?? PhotoCaptureFraming.visibleCrop(
                        imageSize: photoSize,
                        previewSize: previewSize
                    )
                    DispatchQueue.main.async {
                        guard let onScanCapture = self.onScanCapture else {
                            self.captureInProgress = false
                            self.pendingAutoCapture = false
                            return
                        }
                        onScanCapture(data, crop) { [weak self] saved in
                            guard let self else { return }
                            self.captureInProgress = false
                            if saved, self.pendingAutoCapture {
                                self.waitingForNextAutoPage = true
                                self.lastAutoCapturedCrop = self.pendingCaptureDetection?.crop
                                self.stableSince = nil
                                self.previousCrop = nil
                                self.updateCountdown(nil)
                            } else if !saved, self.pendingAutoCapture {
                                self.onDetectionChanged?("Page could not be saved - try again", false)
                            }
                            self.pendingAutoCapture = false
                        }
                    }
                } else {
                    guard let image = UIImage(data: data) else {
                        DispatchQueue.main.async {
                            self.captureInProgress = false
                            self.pendingAutoCapture = false
                        }
                        return
                    }
                    let framed = PhotoCaptureFraming.image(
                        image,
                        matchingAspectFillPreview: previewSize
                    )
                    DispatchQueue.main.async {
                        self.onPhotoCapture?(framed)
                        self.captureInProgress = false
                    }
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
        let orientationState = orientationLock.withLock {
            (visionOrientation, orientationGeneration)
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let rawSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        let currentPreviewImageSize = DocumentCaptureOrientation.orientedSize(
            rawSize,
            orientation: orientationState.0
        )
        guard Date().timeIntervalSince(lastDetectionAt) > 0.08 else { return }
        lastDetectionAt = Date()
        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let observation = (request.results as? [VNRectangleObservation])?.first
            let crop = observation.map {
                DocumentCrop.visionNormalized(
                    topLeft: $0.topLeft,
                    topRight: $0.topRight,
                    bottomRight: $0.bottomRight,
                    bottomLeft: $0.bottomLeft
                )
            }
            DispatchQueue.main.async { [weak self, currentPreviewImageSize] in
                guard let self else { return }
                let currentGeneration = self.orientationLock.withLock { self.orientationGeneration }
                guard currentGeneration == orientationState.1 else { return }
                if let crop {
                    self.latestDetection = DetectedCrop(
                        crop: crop,
                        orientedBufferSize: currentPreviewImageSize,
                        orientationGeneration: orientationState.1
                    )
                    self.previewImageSize = currentPreviewImageSize
                } else {
                    self.latestDetection = nil
                }
                self.handleDetectedCrop(crop)
            }
        }
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumSize = 0.18
        request.quadratureTolerance = 35
        do {
            try visionSequenceHandler.perform(
                [request],
                on: pixelBuffer,
                orientation: orientationState.0
            )
        } catch {
            // A failed frame must not poison the next frame's temporal state.
            visionSequenceHandler = VNSequenceRequestHandler()
        }
    }

    /// Reset temporal Vision state without touching it from the main actor or
    /// the session queue. Stale frames must not influence auto-capture after an
    /// orientation, mode, interruption, or presentation change.
    private func resetVisionSequence() {
        detectionQueue.async { [weak self] in
            self?.visionSequenceHandler = VNSequenceRequestHandler()
        }
    }

    private func handleDetectedCrop(_ detectedCrop: DocumentCrop?) {
        guard mode == .scan else { return }
        guard let crop = detectedCrop else {
            latestDetection = nil
            displayedCrop = nil
            boundaryLayer.removeAllAnimations()
            boundaryLayer.path = nil
            if waitingForNextAutoPage {
                // A temporarily lost edge must not unlock the page gate. Without
                // this, the same page could be auto-captured twice when Vision
                // briefly loses the rectangle after the photo is taken.
                stableSince = nil
                previousCrop = nil
                updateCountdown(nil)
                onDetectionChanged?("Page saved - position the next page", false)
            } else {
                onDetectionChanged?("Point the camera at a document", false)
                resetAutoCaptureState()
            }
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
           DocumentCaptureQuality.hasMovedToNextPage(from: lastAutoCapturedCrop, to: crop) {
            waitingForNextAutoPage = false
        }
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
        latestDetection = nil
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
        var factors = [device.minAvailableVideoZoomFactor, 1]
        factors.append(contentsOf: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) })
        factors.append(contentsOf: CameraZoomOption.preferredDisplayFactors.map { $0 / multiplier })
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
