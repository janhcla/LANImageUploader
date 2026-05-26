# Photo Camera Fidelity and Scan Overlay Design

## Goal

Complete the Photo and Scan camera workflows in PR #41 so Photo capture is
compositionally trustworthy and interactive, while Scan edge feedback is fast
and fluid without weakening the existing non-destructive crop workflow.

## Scope

This change extends the already implemented direct Photo/Scan entry and mode
selector. It adds:

- exact Photo viewfinder-to-saved-image framing,
- tap-to-focus and exposure in the Photo viewfinder,
- device-dependent camera zoom choices,
- a Liquid Glass Photo review experience with interactive image zoom,
- smoother and more responsive Scan document-boundary feedback, and
- the four active code-review corrections on the current PR head.

It does not add photo editing, filters, flash controls, OCR, cloud services, or
changes to Scan export semantics.

## Product Behavior

### Photo Viewfinder Fidelity

Photo mode keeps its full-screen viewfinder layout. The app must save the same
composed field of view the user saw immediately before pressing the shutter.
Since an aspect-fill preview crops the camera sensor image to the display
aspect ratio, Photo output is cropped after capture to the normalized region
visible through the preview layer.

Only Photo output uses this destructive framing crop. Scan output remains an
original captured image accompanied by a non-destructive `DocumentCrop`, so
users can still revise document edges in Gallery View before export/upload.

### Focus and Exposure

A short press within the live camera viewfinder converts the tapped layer
location to a device point, then requests continuous autofocus and exposure at
that point when the active camera supports them. A transient focus reticle
appears at the tap location and fades after confirmation time. Taps on camera
controls must continue to trigger those controls instead of focus.

### Zoom Choices

The camera session uses an appropriate back-camera capture device and derives
selectable zoom choices from that device's usable zoom range. The UI displays
concise magnification chips such as `0.5x`, `1x`, `2x`, or `3x` only when
supported for the current hardware, always including the current base option.
Selecting a chip updates `videoZoomFactor` within the device's supported
bounds and keeps preview, Photo capture, and Scan capture aligned on the same
zoom.

### Photo Review

After a Photo capture, the app presents the framed output in a dark,
glass-styled review surface consistent with the rest of ImageDrop. The review
contains accessible `Discard`, `Retake`, and `Keep Photo` controls.

The captured image supports pinch-to-zoom and drag-to-pan while zoomed, with
double-tap reset/toggle behavior. The interaction is transient review state:
discard or retake returns directly to the live Photo camera; keep saves the
reviewed, correctly framed image to the gallery.

### Scan Edge Feedback

Scan retains Vision rectangle recognition, automatic capture qualification,
multi-page storage, and non-destructive crop metadata. To make the live edge
overlay match the good captured crop behavior:

- rectangle requests run with lower update latency while still discarding
  obsolete video frames,
- the newest raw detected crop is preserved for capture and persisted metadata,
- only the displayed outline is lightly smoothed against recent displayed
  points, and
- shape path updates animate briefly without delaying new detections.

If recognition is lost, the visible outline clears promptly and auto-capture
quality state resets. Overlay smoothing must never replace or distort the raw
crop stored for a captured page.

## Technical Structure

### Pure Helpers

Pure camera geometry and quality operations should be testable without an
active camera:

- derive a normalized visible Photo crop rect from image and view aspect
  ratios,
- crop a captured `UIImage` to that visible Photo region,
- calculate document movement directly from four points,
- calculate quadrilateral area directly with the shoelace formula, and
- smooth only displayed document corner points with a bounded interpolation.

### Capture Controller

`DocumentCameraViewController` continues to own `AVCaptureSession`,
`AVCapturePhotoOutput`, preview presentation, Vision handling, focus, and zoom.
It must:

- apply the same active camera and zoom factor to preview and still output,
- capture Photo with the current preview-visible rect,
- leave Scan image pixels untouched while returning the raw detected crop,
- recognize viewfinder tap gestures for focus/exposure,
- publish supported zoom choices and current selection to SwiftUI,
- keep cross-queue mode reads/writes synchronized, and
- avoid synchronously invoking SwiftUI state mutations during a representable
  update.

### SwiftUI Camera Shell

`ScannerCaptureView` remains responsible for mode controls, guidance, gallery
shortcut, and Photo review presentation. It displays:

- focus feedback over the viewfinder,
- zoom choices in the live control area,
- mode-specific Scan guidance and auto-capture switch, and
- the new glass Photo review with zoomable image presentation.

`CameraView` computes Photo and Scan item totals without independently
filtering the collection twice.

## Code Review Disposition

The four active Gemini review threads are technically applicable:

1. SwiftUI state callbacks triggered through `updateUIViewController` must
   schedule state changes asynchronously on the main queue.
2. `CameraView` must compute scanned pages once and derive non-scan Photo count
   from total retained images.
3. `DocumentCaptureQuality.averageMovement` must avoid per-frame collection
   allocations by calculating four point distances directly.
4. `DocumentCaptureQuality.isAcceptable` must calculate polygon area directly
   rather than constructing intermediate arrays each frame.

The older thread-safety, discard, and localization issues are already corrected
on the current branch and must remain intact.

## Error Handling and Privacy

- If focus, exposure, or a requested zoom factor is unsupported, the live
  camera remains usable with no capture failure.
- Camera-permission failure continues to surface guidance to the user.
- No photo pixels, filenames, device details, or detected document content are
  logged.
- Images remain on-device and retain the existing gallery persistence model.

## Verification

### Automated

- Add Swift Testing coverage for Photo visible-region geometry and image output
  dimensions.
- Extend document-quality tests for direct movement, area qualification, and
  displayed-crop smoothing behavior.
- Run full `LANImageUploader` tests and a simulator build through
  XcodeBuildMCP.

### Simulator

- Confirm Home opens Photo and Scan directly as before.
- Confirm Photo view exposes zoom controls and a focusable viewfinder surface.
- Confirm Photo review displays glass actions and interactive image gestures.
- Confirm discard/retake return to live camera and keep updates its gallery
  count.
- Confirm Scan still exposes auto-capture and responds with the boundary
  overlay without blocking UI interaction.
- Run accessibility audits for live Photo, Photo review, and Scan states.

### Hardware Limitation

Simulator validation can confirm UI, navigation, state transitions, and pure
framing logic. Physical-device smoke testing is still required to visually
confirm real lens zoom choices, autofocus/exposure response, and the final
preview-to-photo field-of-view match on camera hardware.
