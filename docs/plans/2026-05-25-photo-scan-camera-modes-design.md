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
- The Home screen opens the camera directly: `Capture Image` begins in
  `Photo`, and `Scan Documents` begins in `Scan`; the intermediate capture
  prompt screen is removed.
- `Photo` captures manually and opens a review state before saving. The user
  can `Retake`, `Discard`, or `Keep Photo`; discard returns to the live Photo
  camera instead of dismissing capture.
- `Scan` displays detected document boundaries, keeps the page counter and
  Gallery shortcut, and retains the auto-capture toggle.
- Both modes expose a Gallery badge: Photo counts kept non-document photos,
  and Scan counts retained document scans.
- When auto-capture is on, `Scan` displays a visual countdown and emits haptic
  feedback only while a detected rectangle remains sufficiently large,
  straight, and stable. Losing quality cancels the countdown without capture.

## Architecture

`HomeView` presents `CameraView(initialMode:)` as a full-screen cover.
`CameraView` becomes a lightweight camera-session container without the old
Ready to Capture intermediary. `ScannerCaptureView` remains the shared capture
shell and passes the selected mode to `DocumentCameraViewController`. The controller continues to own
AVFoundation and Vision detection; it adds a mode gate and progress callback
for quality-qualified countdown. Photo captures return without a crop and are
held in SwiftUI state until the user confirms them. Scan captures continue to
save a `DocumentCrop` and participate in existing non-destructive editing and
PDF/JPEG export.

The camera controller synchronizes cross-queue access to capture mode because
SwiftUI updates it on the main thread while Vision reads it on the detection
queue. Mode labels use localizable keys rather than dynamic unlocalized text.

## Release Metadata

Set the application marketing version to `1.57`, the app build number to at
least `12`, and retain `ITSAppUsesNonExemptEncryption = false`.

## Verification

- Unit tests for quality qualification/countdown state where logic is pure.
- Simulator build and full test run through XcodeBuildMCP.
- Semantic UI inspection of the mode selector and Photo review controls.
- Accessibility audit of the revised camera view.
