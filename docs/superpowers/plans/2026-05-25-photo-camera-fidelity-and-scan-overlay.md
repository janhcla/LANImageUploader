# Photo Camera Fidelity and Scan Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Photo capture match its viewfinder while adding focus, zoom and a polished review, and make Scan boundary feedback responsive without changing stored crop fidelity.

**Architecture:** Keep the existing SwiftUI camera shell and AVFoundation/Vision controller. Add pure, testable geometry and smoothing helpers, then use them in the controller so Photo frames its confirmed image to the preview, while Scan keeps raw crop metadata and uses a separately smoothed live outline.

**Tech Stack:** SwiftUI, UIKit, AVFoundation, Vision, CoreGraphics, Swift Testing, XcodeBuildMCP, ios-simulator-skill scripts.

---

### Task 1: Test Pure Photo Framing and Scan Overlay Behavior

**Files:**
- Modify: `LANImageUploaderTests/GalleryModelsTests.swift`
- Modify: `LANImageUploader/CameraPicker.swift`

- [ ] **Step 1: Add failing helper tests**

Add tests that call APIs which are not yet present:

```swift
@Test func photoFramingCropsAspectFillOutputToTallPreview() {
    let visible = PhotoCaptureFraming.normalizedVisibleRect(
        imageSize: CGSize(width: 400, height: 300),
        previewSize: CGSize(width: 300, height: 600)
    )
    #expect(abs(visible.width - 0.375) < 0.001)
    #expect(abs(visible.midX - 0.5) < 0.001)
}

@Test func overlaySmoothingMovesTowardLatestDetectedCropWithoutReplacingIt() {
    let first = DocumentCrop.fullFrame
    let second = DocumentCrop(
        topLeft: CGPoint(x: 0.2, y: 0.2),
        topRight: CGPoint(x: 0.8, y: 0.2),
        bottomRight: CGPoint(x: 0.8, y: 0.8),
        bottomLeft: CGPoint(x: 0.2, y: 0.8)
    )
    let display = DocumentCaptureQuality.smoothedDisplayCrop(from: first, toward: second, factor: 0.5)
    #expect(display.topLeft == CGPoint(x: 0.1, y: 0.1))
    #expect(second.topLeft == CGPoint(x: 0.2, y: 0.2))
}
```

- [ ] **Step 2: Run the tests and confirm they fail because helpers do not exist**

Run the `LANImageUploader` test target through XcodeBuildMCP. Expected result:
compile failure naming `PhotoCaptureFraming` and `smoothedDisplayCrop`.

- [ ] **Step 3: Add pure helper implementations**

Implement `PhotoCaptureFraming.normalizedVisibleRect`, image-cropping support,
direct point-distance and shoelace calculations in `DocumentCaptureQuality`,
and:

```swift
static func smoothedDisplayCrop(
    from displayed: DocumentCrop?,
    toward latest: DocumentCrop,
    factor: CGFloat = 0.42
) -> DocumentCrop
```

The smoothing helper interpolates each control point independently and never
mutates the raw crop supplied as `latest`.

- [ ] **Step 4: Run tests and confirm the new pure behavior passes**

Run the full test target through XcodeBuildMCP. Expected result: all preexisting
tests plus the new framing/smoothing tests pass.

### Task 2: Correct Review Feedback and Captured Item Counting

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Modify: `LANImageUploader/CameraView.swift`

- [ ] **Step 1: Schedule representable callbacks safely**

Change callbacks created by `ScannerCaptureView` so state mutations are
scheduled asynchronously:

```swift
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
}
```

- [ ] **Step 2: Count retained items once**

In `CameraView.body`, derive both badge values from one scan-page calculation:

```swift
let scannedCount = appData.images.filter(\.isDocumentScan).count
let keptCount = appData.images.count - scannedCount
return ScannerCaptureView(
    initialMode: initialMode,
    keptPhotoCount: keptCount,
    scannedPageCount: scannedCount,
    ...
)
```

- [ ] **Step 3: Build after review fixes**

Run a simulator build through XcodeBuildMCP. Expected result: no Swift compile
failures and no new build diagnostics from the callback/count changes.

### Task 3: Add Photo Viewfinder Fidelity, Focus and Zoom

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

- [ ] **Step 1: Frame Photo output to the preview**

Record `previewLayer.bounds.size` when a Photo capture starts and pass
processed Photo output through:

```swift
PhotoCaptureFraming.image(image, matchingAspectFillPreview: pendingPhotoPreviewSize)
```

Keep Scan delivery unchanged:

```swift
onScanCapture?(image, pendingCaptureCrop)
```

- [ ] **Step 2: Add tap-to-focus/exposure**

Install a tap gesture recognizer on the preview controller and convert the
touch location via `previewLayer.captureDevicePointConverted(fromLayerPoint:)`.
Configure supported `.continuousAutoFocus` and `.continuousAutoExposure`
points on the active device under `lockForConfiguration`, then draw a transient
focus reticle on the controller overlay.

- [ ] **Step 3: Add supported zoom choices**

Select the best available back virtual camera, derive `CameraZoomOption` values
from `virtualDeviceSwitchOverVideoZoomFactors`, the available bounds, and
`displayVideoZoomFactorMultiplier`, and expose them to SwiftUI. Selecting an
option sets a clamped `videoZoomFactor` on the same active device used by the
preview and still output.

- [ ] **Step 4: Build and exercise the Photo live view**

Build/run on the simulator, open Photo from Home, and confirm semantic camera
controls include shutter, Gallery and zoom choices. Physical-device validation
of optical lenses and focus response remains required after merge.

### Task 4: Build Glass Photo Review with Interactive Zoom

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`

- [ ] **Step 1: Introduce zoomable review image presentation**

Add a focused SwiftUI review component that tracks accumulated scale and
translation using `MagnifyGesture` and `DragGesture`, supports double-tap
reset/toggle, and clips its image inside a rounded glass-backed presenter.

- [ ] **Step 2: Restyle actions consistently**

Present `Discard`, `Retake`, and `Keep Photo` inside `GlassContainer` controls,
preserving existing action semantics and accessibility labels. `Discard` and
`Retake` must set `photoReviewImage = nil`; `Keep Photo` must save exactly the
framed reviewed image.

- [ ] **Step 3: Exercise review flow semantically**

Use `screen_mapper.py` and `navigator.py` to take a Photo, assert the three
review actions are reachable, discard/retake returns to the live view, and
keep increments the Photo Gallery badge.

### Task 5: Smooth Scan Overlay Without Altering Raw Crop

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

- [ ] **Step 1: Increase recognition responsiveness**

Lower the detection throttle from its current visibly delayed interval, while
retaining `alwaysDiscardsLateVideoFrames`, one rectangle observation, and
capture qualification gates.

- [ ] **Step 2: Split raw and displayed crop state**

Keep `latestCrop` as the raw Vision result used for pending Scan capture. Add a
separate displayed crop updated through
`DocumentCaptureQuality.smoothedDisplayCrop` and draw only that displayed
value.

- [ ] **Step 3: Animate boundary rendering briefly**

Apply a short `CABasicAnimation` for path transitions and disable stale
animations when no rectangle is found or the user switches away from Scan.

- [ ] **Step 4: Verify scan UI and pure smoothing tests**

Open Scan in the simulator, confirm auto-capture and boundary UI remain
accessible, then run the test suite to confirm crop persistence behavior still
passes.

### Task 6: Verify and Publish

**Files:**
- Modify: `docs/feature-test-coverage.md`

- [ ] **Step 1: Update feature coverage documentation**

Record the new Photo framing/focus/zoom/review interactions, smoothed Scan
overlay behavior, and physical-camera validation limitation.

- [ ] **Step 2: Run final verification**

Run:

```text
git diff --check
XcodeBuildMCP build_run_sim with -skipPackagePluginValidation -skipMacroValidation
XcodeBuildMCP test_sim with -skipPackagePluginValidation -skipMacroValidation
ios-simulator-skill screen_mapper.py / navigator.py / accessibility_audit.py
```

Expected result: build and tests pass; no critical accessibility findings on
the revised Photo and Scan states.

- [ ] **Step 3: Commit and push the branch**

Commit the source, tests, plan, and documentation to
`codex/photo-scan-camera-modes`, then push the branch to `origin` and re-read
PR #41 status/check results.
