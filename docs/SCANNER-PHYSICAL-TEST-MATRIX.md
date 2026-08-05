# Scanner and PDF physical test matrix

This protocol is the release gate for behavior that an iOS Simulator cannot
prove: camera focus and exposure, rectangle alignment, thermal behavior,
memory pressure, interruptions, and a real SMB/Windows import workflow.

## Current simulator evidence

On 2026-07-26, the current LensBridge simulator build was launched on the
configured iPhone 17 Pro simulator. The full suite passed (64 passed, 0 failed,
0 skipped, 88 discovered). A fresh idle-process memgraph and a second memgraph
captured while the process was on the document-scanner screen both summarized as
**0 leaks / 0 bytes**:

- Idle capture and summary: `/tmp/lensbridge-memgraph.XWJ3R2/`
- Scanner-screen capture and summary: `/tmp/lensbridge-scanner-memgraph.hxUuE4/`

These are useful lifecycle baselines only; they do not replace the 50-/100-page
scanner/Gallery Instruments runs below, because the simulator flow did not
exercise a physical camera, real pages, thermal pressure, or SMB.

The current attached production App Store candidate is build 65. The latest
historical TestFlight validation build is build 64. Attachment does not close the
physical release gate; real-device scanning, memory, and SMB/Windows tests still
remain required before submission.

The configured physical iPhone is currently reported as `disconnected` and
`isAvailable=false`. No physical-device test was run or claimed from this
remote session.
The automated PDF regression creates and verifies a 100-page sequential document
without dropping pages. This is still a writer/integrity test, not a camera or
memory-pressure proof. The current full-suite result bundle is:
`~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T23-14-55-932Z_pid7794_ab824aef.xcresult`.

The current semantic UI smoke also exposes labeled Home, Settings, Help Center,
and scanner-guide targets. This is useful navigation/accessibility evidence, but
it is not a substitute for a formal WCAG audit or physical-device testing.
The physical Instruments gate below therefore remains open.

The latest post-change XcodeBuildMCP run on 2026-07-26 passed 64 tests with
0 failures and 0 skips (88 discovered), including the 100-page sequential PDF
regression, cancelled-PDF cleanup, local-delete failure preservation, retake
failure handling, archive deletion integrity, and the sequence-aware Vision
detector compilation path. The
Gallery PDF flow keeps a cancellable task handle and propagates cancellation to
the detached renderer; JPEG preparation does the same and removes already
generated temporary files. Retake replacement keeps the old Gallery entry when
the old file cannot be removed, and archived-image deletion retains failed
items selected for retry. The current result bundle is:
`~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T22-58-19-517Z_pid45063_9387a258.xcresult`.
This verifies compilation and simulator behavior, but not physical-camera
alignment, peak memory, thermal behavior, or SMB/Windows ingestion.

A subsequent fresh regression on 2026-07-26 again discovered 88 tests and passed
64 with 0 failures and 0 skips. Its result bundle is:
`~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T23-41-37-995Z_pid12229_d3dcba8a.xcresult`.

The memgraph captures above are clean idle/scanner-screen baselines only; they
are not evidence that a 50/100-page capture, cancellation, or physical-camera
flow has no memory growth.

## Test hygiene

- Use a test iPhone and synthetic documents only. Do not use patient data,
  real CPR numbers, real server credentials, or a production journal folder.
- Record device model, iOS version, app build, camera lens/zoom, lighting,
  Wi-Fi/VPN state, and the exact test case ID.
- Capture only aggregate metrics and synthetic filenames in the report.
- Keep the original local Gallery files until PDF creation and upload integrity
  have been verified.

## Device matrix

Run the full matrix on the oldest supported iPhone and iOS version, one current
baseline iPhone, and the largest supported iPhone. At minimum include:

| Device condition | Required evidence |
| --- | --- |
| Fresh install, camera allowed | Permission prompt, preview, photo and scan capture |
| Camera denied, then enabled in Settings | In-app guidance and successful retry |
| Portrait and landscape | Overlay alignment, saved crop and PDF orientation |
| Low light, glare, patterned background | No premature auto-capture or unusable crop |
| Wi-Fi reachable / isolated / VPN active | Correct connection error and recovery path |
| App backgrounded during capture and PDF generation | No crash, duplicate page, or lost saved page |
| Incoming call/FaceTime or camera interruption | Capture state recovers or fails safely |

## Scanner cases

For each case, record page count, duplicate pages, missed pages, crop quality,
rotation, time to first page, and time to finish.

1. One clean A4 page, portrait and landscape.
2. Ten pages with alternating portrait/landscape orientation.
3. Twenty-five pages with page movement between captures.
4. Fifty pages under continuous use; monitor thermal state and peak memory.
5. One hundred pages, or the largest safe batch the device can sustain.
6. Partial page, skewed page, glossy page, shadow across an edge, and low light.
7. Auto-capture on: hold a page still, move it away, then present the next page.
8. Auto-capture off: manually capture the same cases.
9. Rotate the device during detection and immediately after a capture.
10. Leave the scanner and return repeatedly; verify the delegate and session do
    not duplicate work or leave the UI stuck.

## Gallery and PDF cases

- Open a 100-page gallery and scroll from first to last page repeatedly.
- Open and dismiss several fullscreen images; watch for progressive memory growth.
- Reorder, rotate, crop-edit, rename, archive, delete, and restore pages.
- Generate A4 and Letter PDFs with Fit and Fill layouts, with and without page
  numbers, at every compression profile.
- Cancel or background generation; verify a partial PDF is not offered as a
  completed upload and source pages remain in Gallery.
- Parse the PDF page count and confirm page order, page dimensions, JPEG image
  presence, and readable output in Preview/Files.

## Upload and journal-boundary cases

- Run `Test Connection` against a synthetic SMB share with valid credentials,
  invalid credentials, missing share, missing target directory, and no route.
- Upload one JPEG, a mixed batch, and a multi-page PDF to a disposable target
  folder. Verify filenames, byte counts, and ordering independently on Windows.
- Confirm the app reports upload success separately from the journal/watch-folder
  ingest result. Test the latter only in a vendor-approved synthetic workflow.
- Interrupt Wi-Fi and reconnect during a batch; verify retry/partial-batch
  behavior and that no source page is silently deleted.

## Instruments evidence

For the 50- and 100-page cases, capture Allocations and Leaks traces and record:

- peak resident memory;
- memory after returning from Gallery to Home;
- number of live `UIImage`, `CGImage`, `CIImage`, and PDF-related objects;
- CPU time and thermal state during detection and PDF creation;
- whether memory returns near baseline after dismissal and cancellation.

Any repeatable growth, crash, duplicate page, missing page, or orphaned temporary
file is a release blocker until fixed or explicitly accepted by the owner.

## External implementation review

For each reference repository in the release plan, capture the repository URL,
commit/ref, license, maintenance status, and the specific lesson adopted. Review
architecture and behavior; do not copy code without a compatible license and an
explicit attribution decision.
