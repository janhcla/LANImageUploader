# Scanner Audio Preservation and Crop Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve external audio during camera use and make document crop coordinates reliable across video detection, still capture, Gallery, JPEG, and PDF rendering.

**Architecture:** Keep `DocumentCrop` as top-left normalized coordinates in the upright saved image. Capture orientation and source geometry with each Vision result, transform it into the upright photo coordinate system, validate it, and make rendering fail closed to the original image.

**Tech Stack:** Swift, SwiftUI, AVFoundation, Vision, Core Image, Swift Testing, Xcode.

---

### Task 1: Audio-Safe Camera Configuration

**Files:**
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

- [ ] Add a failing unit test for a `ScannerCapturePolicy` whose automatic audio-session configuration and audio capture flags are both false.
- [ ] Run the focused test and verify it fails because the policy does not exist.
- [ ] Add the policy, set `session.automaticallyConfiguresApplicationAudioSession = false`, and assert that only a video input is created.
- [ ] Set the legacy image picker to `public.image` and `.photo`.
- [ ] Add DEBUG-only interruption and route-change observers with privacy-safe logging.
- [ ] Run the focused tests and build.
- [ ] Commit the audio-only change.

### Task 2: Canonical Crop Geometry

**Files:**
- Modify: `LANImageUploader/GalleryModels.swift`
- Modify: `LANImageUploader/CameraPicker.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

- [ ] Add failing tests for Vision conversion, portrait/landscape aspect mapping, valid A4 geometry, tiny crops, crossing points, out-of-bounds points, and flat/skewed crops.
- [ ] Run focused tests and verify the new tests fail.
- [ ] Implement canonical coordinate conversion, aspect-fill mapping, and robust validation in `DocumentCrop`.
- [ ] Replace hardcoded Vision `.up` with interface-orientation-derived `CGImagePropertyOrientation`.
- [ ] Store detection orientation, image size, and an orientation generation with the latest crop.
- [ ] Normalize still photos upright and transform only current, valid crop metadata into still-image coordinates.
- [ ] Clear detections on orientation changes.
- [ ] Run focused tests and commit the coordinate pipeline.

### Task 3: Rendering Guardrails and Scan Classification

**Files:**
- Modify: `LANImageUploader/GalleryModels.swift`
- Modify: `LANImageUploader/CameraPicker.swift`
- Modify: `LANImageUploader/CameraView.swift`
- Modify: `LANImageUploader/AppData.swift`
- Test: `LANImageUploaderTests/GalleryModelsTests.swift`

- [ ] Add failing tests that invalid perspective crops return original dimensions/content and valid crops return non-empty, non-black output.
- [ ] Add a failing test proving a document scan can remain classified as a scan when crop metadata is nil.
- [ ] Run focused tests and verify failures.
- [ ] Validate Core Image input vectors and output extent before rendering.
- [ ] Detect implausibly black corrected output using a bounded render and fall back to the source.
- [ ] Change scan capture callback to accept an optional crop and save scans with explicit `isDocumentScan`.
- [ ] Run focused tests and commit guardrails.

### Task 4: Verification and PR

**Files:**
- Modify: `docs/superpowers/plans/2026-06-10-scanner-audio-crop.md`

- [ ] Run the full unit test suite on `LANImageUploader iPhone 17 Pro` with iOS 26.5.
- [ ] Run a clean simulator build.
- [ ] Inspect the final diff for credentials, patient data, microphone usage descriptions, audio inputs, and unrelated changes.
- [ ] Mark completed plan steps.
- [ ] Push the branch and open a draft PR with root causes, exact fixes, automated verification, and an explicit real-device QA checklist.
- [ ] Do not claim real-device audio or camera acceptance criteria are complete unless physically tested.
