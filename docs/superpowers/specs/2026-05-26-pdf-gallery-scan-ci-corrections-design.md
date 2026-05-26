# PDF, Gallery, Scan Overlay and CI Corrections Design

## Goal

Reduce scanned PDF size with user-selectable compression, preserve camera
workflow intent when opening Gallery, make post-upload deletion consistent,
correct the live document outline and scan thumbnail presentation, and remove
the Xcode Cloud launch-test instability affecting PR #41.

## Scope

This change extends the Photo and Scan camera work already present on
`codex/photo-scan-camera-modes`. It includes:

- PDF compression levels configured in Settings,
- camera-mode-sensitive Gallery output selection,
- destructive clearing of original gallery images after successful uploads,
- correct live preview mapping for detected Scan boundaries,
- full-page scan thumbnails, and
- deterministic UI launch coverage for Xcode Cloud.

It does not change server upload protocols, add cloud storage, add OCR export,
or destructively crop scan originals before export.

## Product Behavior

### PDF Compression

Settings exposes three understandable compression choices: `Light`, `Medium`,
and `High`. The selected choice applies only when producing PDF pages and is
persisted between app launches.

Each level defines both the JPEG compression quality and the maximum image
dimension used for PDF embedding. This avoids embedding multi-megapixel page
images without recompression while retaining legible document output. Medium
is the initial default and balances readable printed text against transfer
size.

### Gallery Output From Camera

The active mode at the moment the user taps the Gallery shortcut controls the
initial Gallery output mode:

- Scan opens with `Single PDF` selected.
- Photo opens with `Separate Images` selected.

Opening Gallery outside the camera continues to honor the default setting
configured in Settings. Changing modes inside the camera before tapping the
shortcut must be respected.

### Successful Upload Deletion

Once all files in Upload View have uploaded successfully, the destructive
delete action removes the retained gallery images and all temporary prepared
upload files. This applies to both separate image derivatives and a generated
PDF. Gallery therefore reflects the explicit delete choice immediately.

### Scan Outline Rendering

The persisted `DocumentCrop` remains in normalized top-origin coordinates and
continues to drive the later non-destructive crop. The live yellow outline
must no longer feed those coordinates into capture-device conversion APIs.
Instead, it maps normalized points into the aspect-fill rectangle occupied by
the oriented camera frame in the preview bounds. This keeps overlay rendering
separate from export geometry and aligns the outline with what the user sees.

### Scan Thumbnails

Document scans use a fit presentation inside the existing thumbnail card so
the complete corrected page is visible. Ordinary photos retain the existing
fill behavior.

### Xcode Cloud Launch Test

The screenshot launch test runs once rather than for every generated UI
configuration and checks that the application reaches foreground state before
capturing a screenshot. The launch performance measurement remains useful
locally but is skipped under Xcode Cloud, where repeated launches have no
functional coverage benefit and caused the current timeout.

## Technical Structure

### Models and Settings

- Add `PDFCompressionLevel` beside existing PDF model enums.
- The enum exposes display text, `jpegQuality`, and `maxPixelDimension`.
- Persist selection through `AppData` and a new UserDefaults key.
- Replace the misleading raw PDF JPEG slider with the compression-level
  picker in both Settings presentations.

### PDF Generation

`PDFGenerationService` renders each corrected page at the selected maximum
dimension, converts it to JPEG data using the selected quality, then draws
the decoded compressed image into the PDF renderer. Failure to produce or
decode page JPEG data is treated as generation failure rather than silently
writing an uncompressed page.

### Navigation and Deletion

- `ScannerCaptureView` reports its currently selected `CameraCaptureMode` when
  the gallery shortcut is tapped.
- `CameraView` converts that mode to an optional initial
  `GalleryOutputMode` override.
- `GalleryView` uses an initial override only when provided; otherwise it uses
  the user default.
- `AppData` owns deletion of retained images so Upload View calls a single,
  testable deletion path after removing temporary pending uploads.

### Preview Geometry

Add a pure `DocumentPreviewGeometry` helper that calculates an aspect-fill
content rectangle and transforms normalized `DocumentCrop` corners into layer
points. `DocumentCameraViewController` records the oriented sample frame size
and uses this helper for boundary drawing. Capture continues to store raw
crop values.

## Verification

- Swift Testing coverage for compression profiles, aspect-fill crop mapping,
  and deletion of retained images after prepared uploads.
- Build and test the app through XcodeBuildMCP.
- Exercise Gallery routing and thumbnail appearance in the simulator using
  semantic automation where accessible.
- Run the UI tests with the cloud-stability changes in place.

Actual live outline alignment still requires a physical-device document scan
smoke test because the iOS Simulator does not provide representative camera
geometry.
