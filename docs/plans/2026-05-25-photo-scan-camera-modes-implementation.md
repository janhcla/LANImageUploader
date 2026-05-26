# Photo and Scan Camera Modes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Provide dedicated Photo and Scan camera workflows with guarded document auto-capture and release metadata updates.

**Architecture:** Extend the existing SwiftUI capture shell and AVFoundation/Vision controller rather than add another camera stack. Keep document crop persistence and exports intact, while Photo mode reviews a transient image before it is added to the gallery.

**Tech Stack:** SwiftUI, AVFoundation, Vision, UIKit haptics, Swift Testing, XcodeBuildMCP.

---

### Task 1: Define Camera Modes and Quality Progress

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

**Steps:**
1. Add `Photo` and `Scan` mode state plus callbacks for un-cropped photo capture and scan countdown progress.
2. Gate Vision-driven auto-capture to Scan mode only.
3. Require stable rectangle geometry and minimum document coverage before advancing countdown.
4. Reset countdown immediately when the quality gate fails.

### Task 2: Implement Photo Review and Scan UX

**Files:**
- Modify: `LANImageUploader/HomeView.swift`
- Modify: `LANImageUploader/CameraPicker.swift`
- Modify: `LANImageUploader/CameraView.swift`

**Steps:**
1. Launch `CameraView(initialMode: .photo)` directly from `Capture Image` and
   add `Scan Documents` launching `CameraView(initialMode: .scan)` directly.
2. Remove the intermediate Ready to Capture screen from `CameraView`.
3. Add an accessible, localizable mode selector to the full-screen camera.
4. Present manual Photo capture with `Retake`, `Discard`, and `Keep Photo`;
   discard and retake both return to the live Photo preview.
5. Expose a mode-specific Gallery badge in both Photo and Scan modes while
   keeping auto-capture and document overlay Scan-only.
6. Synchronize `DocumentCameraViewController.mode` access between SwiftUI and
   its detection queue.
7. Surface countdown guidance and haptics while Scan auto-capture is qualified.

### Task 3: Update Release Metadata

**Files:**
- Modify: `LANImageUploader.xcodeproj/project.pbxproj`
- Verify: `LANImageUploader/Info.plist`

**Steps:**
1. Set application `MARKETING_VERSION` to `1.57`.
2. Set application `CURRENT_PROJECT_VERSION` to `12` or higher.
3. Verify `ITSAppUsesNonExemptEncryption` remains `false`.

### Task 4: Verify and Publish

**Files:**
- Modify tests only if new pure behavior requires coverage.

**Steps:**
1. Run diff validation.
2. Build and test on the configured iPhone simulator with XcodeBuildMCP.
3. Inspect Photo/Scan controls semantically and run an accessibility audit.
4. Commit and push `codex/photo-scan-camera-modes`.
