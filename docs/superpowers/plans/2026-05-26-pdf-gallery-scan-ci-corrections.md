# PDF, Gallery, Scan Overlay and CI Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make document PDF output compact and configurable while correcting camera-to-gallery state, gallery deletion, scan rendering, thumbnail presentation, and Xcode Cloud launch stability.

**Architecture:** Extend existing value models and `AppData` storage for PDF compression; keep rendering, navigation, and deletion responsibilities in their current owning modules. Introduce one pure preview geometry transform so the camera controller draws persisted normalized crop coordinates correctly without changing saved scan data.

**Tech Stack:** SwiftUI, UIKit, AVFoundation, Vision, UIGraphicsPDFRenderer, Swift Testing, XCTest, XcodeBuildMCP.

---

### Task 1: PDF Compression Profile and Export

**Files:**
- Modify: `LANImageUploader/GalleryModels.swift`
- Modify: `LANImageUploader/Constants.swift`
- Modify: `LANImageUploader/AppData.swift`
- Modify: `LANImageUploader/SettingsView.swift`
- Modify: `LANImageUploader/GalleryView.swift`
- Modify: `LANImageUploader/Services/PDFGenerationService.swift`
- Test: `LANImageUploaderTests/LANImageUploaderTests.swift`

- [ ] **Step 1: Write failing model tests**

Add tests asserting `PDFCompressionLevel.medium.jpegQuality` and dimensions
are stricter than `.light`, and `.high` is stricter than `.medium`.

- [ ] **Step 2: Run tests and confirm missing-level failure**

Run the `LANImageUploaderTests` test target; expect compilation failure because
`PDFCompressionLevel` does not exist yet.

- [ ] **Step 3: Implement compression level persistence and UI**

Add:

```swift
enum PDFCompressionLevel: String, CaseIterable, Identifiable, Codable {
    case light, medium, high
    var id: String { rawValue }
    var jpegQuality: CGFloat { /* profile value */ }
    var maxPixelDimension: CGFloat { /* profile value */ }
    var displayName: String { /* localized display title */ }
}
```

Persist `pdfCompressionLevel` through `@AppStorage`, present it in both PDF
Settings sections, and pass the derived profile into `PDFSettings`.

- [ ] **Step 4: Recompress embedded PDF pages**

In `PDFGenerationService`, render at the profile dimension, create JPEG data
using `settings.jpegQuality`, decode that data to the image drawn into each
PDF page, and throw an export error if compression fails.

- [ ] **Step 5: Run tests and build**

Run model tests and a simulator build; expect zero failures and no compiler
errors.

### Task 2: Camera Context Routing and Full-Page Thumbnails

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Modify: `LANImageUploader/CameraView.swift`
- Modify: `LANImageUploader/GalleryView.swift`
- Modify: `LANImageUploader/GalleryItemView.swift`

- [ ] **Step 1: Pass current mode through gallery action**

Change `onOpenGallery` to accept `CameraCaptureMode`, invoke it with the
current `mode`, store the corresponding output mode in `CameraView`, and
initialize `GalleryView` with that optional override.

- [ ] **Step 2: Preserve non-camera defaults**

Initialize `GalleryView(initialOutputMode:)` so `nil` applies
`appData.defaultGalleryOutputMode`, while `.singlePDF` and `.separateImages`
remain selected when supplied from camera context.

- [ ] **Step 3: Render scan thumbnails in fit mode**

For `capturedImage.isDocumentScan`, place the rendered thumbnail using
`scaledToFit()` within the existing bounded card; retain `scaledToFill()` for
photo thumbnails.

- [ ] **Step 4: Build and exercise navigation**

Build, then open Photo and Scan from Home in the simulator and use each
gallery shortcut; expect respective segmented choices and full scan page
thumbnail visibility.

### Task 3: Delete Retained Gallery Images After Upload

**Files:**
- Modify: `LANImageUploader/AppData.swift`
- Modify: `LANImageUploader/UploadView.swift`
- Test: `LANImageUploaderTests/LANImageUploaderTests.swift`

- [ ] **Step 1: Write failing deletion test**

Add a test with `appData.images` populated and assert a new async
`deleteAllRetainedImages()` removes every underlying file and empties images.

- [ ] **Step 2: Run test and confirm missing-method failure**

Run the targeted test; expect failure because deletion has not yet been
centralized in `AppData`.

- [ ] **Step 3: Implement centralized deletion**

Implement `AppData.deleteAllRetainedImages()` to remove stored file URLs,
empty `images` and selection on the main actor, then have Upload View call it
after deleting any prepared pending files.

- [ ] **Step 4: Verify deletion tests**

Run the targeted and full unit test suite; expect all retained pages removed
for the destructive post-upload action.

### Task 4: Correct Live Scan Boundary Mapping

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/LANImageUploaderTests.swift`

- [ ] **Step 1: Write failing geometry test**

Add tests for a portrait normalized document mapped through an aspect-fill
preview, asserting corner positions stay aligned to the expected displayed
content rectangle rather than capture-device transformed coordinates.

- [ ] **Step 2: Run test and confirm missing-helper failure**

Run the targeted unit test; expect compilation failure because
`DocumentPreviewGeometry` is absent.

- [ ] **Step 3: Implement pure preview transform**

Add `DocumentPreviewGeometry` with an aspect-fill rectangle calculation and
normalized-point-to-preview mapping using the oriented sample frame size.
Cache that oriented size as frames arrive and draw boundary paths with this
helper.

- [ ] **Step 4: Run geometry tests and build**

Run the targeted test and simulator build; expect passing geometry assertions
and compilation.

### Task 5: Stabilize Xcode Cloud Launch Tests

**Files:**
- Modify: `LANImageUploaderUITests/LANImageUploaderUITestsLaunchTests.swift`
- Modify: `LANImageUploaderUITests/LANImageUploaderUITests.swift`

- [ ] **Step 1: Make launch smoke deterministic**

Set `runsForEachTargetApplicationUIConfiguration` to `false`, launch once,
assert `.runningForeground` within a bounded timeout, and then capture the
screenshot.

- [ ] **Step 2: Avoid CI-only performance launch loops**

Skip `testLaunchPerformance()` when
`ProcessInfo.processInfo.environment["CI_XCODE_CLOUD"] == "TRUE"` while
leaving local launch measurement available.

- [ ] **Step 3: Execute UI tests**

Run the UI test target on the configured simulator; expect a single launch
screenshot smoke run and no cloud-only performance loop locally unless the CI
environment variable is set.

### Task 6: Final Verification and Publication

**Files:**
- Inspect: all modified files and git diff

- [ ] **Step 1: Run full build and tests**

Use XcodeBuildMCP to build and test `LANImageUploader` on the configured iOS
simulator. Run semantic screen inspection/accessibility checks for reachable
modified screens.

- [ ] **Step 2: Inspect change scope**

Run `git diff --check`, `git status --short --branch`, and inspect staged
changes to ensure only this feature set is committed.

- [ ] **Step 3: Commit and push**

Commit the specification, plan, implementation, and tests to
`codex/photo-scan-camera-modes`, then push to `origin` so PR #41 receives the
new revision.
