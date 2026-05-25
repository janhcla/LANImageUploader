# Photo and Scan Camera Modes Design

## Goal

Add an explicit capture-mode switch so ordinary photographs and document scans
have separate, predictable capture workflows while preserving the local gallery
and non-destructive document editing pipeline.

## Reference Features

The design adopts the narrow scanning conventions documented in current App
Store listings for Genius Scan, SwiftScan, and Adobe Scan: visible edge
detection, automatic document capture only when conditions are good, corrected
document geometry, and multi-page scanning. It deliberately does not add OCR,
cloud storage, AI features, signing, or subscriptions.

## UX

- `Photo` and `Scan` are selectable in the full-screen camera view.
- `Photo` captures manually and opens a review state before saving. The user
  can `Retake`, `Discard`, or `Keep Photo`.
- `Scan` displays detected document boundaries, keeps the page counter and
  Gallery shortcut, and retains the auto-capture toggle.
- When auto-capture is on, `Scan` displays a visual countdown and emits haptic
  feedback only while a detected rectangle remains sufficiently large,
  straight, and stable. Losing quality cancels the countdown without capture.

## Architecture

`ScannerCaptureView` becomes the shared capture shell and passes the selected
mode to `DocumentCameraViewController`. The controller continues to own
AVFoundation and Vision detection; it adds a mode gate and progress callback
for quality-qualified countdown. Photo captures return without a crop and are
held in SwiftUI state until the user confirms them. Scan captures continue to
save a `DocumentCrop` and participate in existing non-destructive editing and
PDF/JPEG export.

## Release Metadata

Set the application marketing version to `1.57`, the app build number to at
least `12`, and retain `ITSAppUsesNonExemptEncryption = false`.

## Verification

- Unit tests for quality qualification/countdown state where logic is pure.
- Simulator build and full test run through XcodeBuildMCP.
- Semantic UI inspection of the mode selector and Photo review controls.
- Accessibility audit of the revised camera view.
