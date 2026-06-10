# Scanner Audio Preservation and Crop Reliability Design

## Goal

Keep external audio playing throughout ImageDrop camera and scanner use, and ensure document scans never render as a small valid region surrounded by black output.

## Root-Cause Model

The repository contains no explicit `AVAudioSession` category or activation calls. The custom `AVCaptureSession` therefore retains its default ability to configure the application audio session. The legacy `UIImagePickerController` also does not explicitly restrict capture to still images.

Rectangle detection runs against `AVCaptureVideoDataOutput` buffers while the saved image comes from `AVCapturePhotoOutput`. The current code passes Vision a hardcoded `.up` orientation and stores the resulting normalized points directly against the still image. Video and photo outputs can differ in orientation and aspect ratio, so those points are not guaranteed to describe the same pixels. Crop processing also clamps malformed points and trusts any Core Image output, allowing invalid geometry to become a mostly black image.

## Audio Design

- Set `AVCaptureSession.automaticallyConfiguresApplicationAudioSession` to `false` before configuring or starting the custom session.
- Add only a `.video` camera device input. Do not create an audio input, activate `AVAudioSession`, or request microphone access.
- Configure `UIImagePickerController` with `mediaTypes = ["public.image"]` and `cameraCaptureMode = .photo`.
- Add DEBUG-only observers for audio interruption and route-change notifications. Log only notification type/reason and remove observers when the controller is released.
- Keep audio policy as a small testable value describing that automatic session configuration and audio capture are disabled.

## Crop Coordinate Design

`DocumentCrop` is normalized `0...1` in the upright saved image, with a top-left origin and points ordered clockwise:

`topLeft -> topRight -> bottomRight -> bottomLeft`.

Vision observations are converted from lower-left coordinates to this canonical top-left system. Detection records the orientation and oriented sample-buffer aspect ratio with each crop. At photo completion, the photo is normalized to upright pixels. The crop is mapped between the oriented detection image and upright still image using their aspect-fill relationship, matching the shared camera field of view. The mapped crop is stored only when its orientation generation still matches the capture and its geometry validates.

Orientation changes clear the latest detection so a crop from the previous orientation cannot be reused.

## Validation and Fallback

Crop validation rejects:

- non-finite or materially out-of-bounds points;
- incorrect clockwise ordering or self-intersection;
- area below the configured threshold;
- very short edges or flat quadrilaterals;
- extreme opposing-edge asymmetry or implausible aspect ratio.

Invalid capture geometry is reported as `crop = nil`; the original upright image is saved as a document scan. `CapturedImage.isDocumentScan` is therefore passed explicitly rather than inferred only from crop presence.

`DocumentImageProcessor` validates geometry before perspective correction and validates the resulting extent. It renders a bounded preview to estimate near-black coverage. Empty, non-finite, excessively large, implausibly shaped, or mostly black results fall back to the original image. Gallery thumbnails, fullscreen previews, JPEG exports, and PDF generation already use this processor and therefore share the fallback.

## Testing

- Unit-test Vision lower-left to canonical top-left conversion.
- Unit-test orientation and aspect-fill mapping for portrait and landscape.
- Unit-test crop validation for normal, tiny, out-of-bounds, crossing, flat, and highly skewed quadrilaterals.
- Unit-test normalized-to-Core-Image pixel mapping.
- Unit-test perspective-correction fallback and valid non-black output.
- Unit-test the scanner audio policy and explicit scan classification without crop metadata.
- Build and run the full test suite on the configured iOS simulator.

## Manual QA Boundary

Simulator tests cannot prove that Music, Podcasts, Spotify, or Audible continue on a physical device, and simulator camera input cannot fully reproduce live portrait/landscape document detection. The PR must clearly mark real-device audio and scan-orientation checks as required and must not claim those acceptance criteria are complete until performed.
