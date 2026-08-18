# App Store release plan

Status: 2026-08-05

This is the working release plan for the first public release of the app now
branded `LensBridge` in App Store Connect. It is deliberately written as a gate
plan: a green compile or unit-test run is not enough to call the app release-ready.

## Verified baseline

- App Store Connect app: `6742799620` (`LensBridge`)
- Selected product name: `LensBridge`
- Selected subtitle: `Private Photo & Scan Transfer`
- App Review contact: configured in App Store Connect; personal contact details
  are not recorded in this repository.
- A reproducible local gate is available at `scripts/release_preflight.sh`. It
  checks metadata, screenshots, signed production/TestFlight IPA separation,
  privacy manifest, encryption declaration, ASC version/build attachment, free
  app pricing, IAP type/price, en-US/da name and subtitle, territory
  availability, and ASC review status. Override the build/IPA environment
  variables when the release candidate changes, including
  `MARKETING_VERSION`, `PRODUCTION_BUILD_NUMBER`, and
  `TESTFLIGHT_BUILD_NUMBER`; use `SKIP_ASC=1` for offline artifact-only checks.
- On 2026-07-26, `SKIP_ASC=1 scripts/release_preflight.sh` passed all local
  checks. The active ASC submission is locked in `WAITING_FOR_REVIEW`, so the
  remaining ASC doctor warning is the expected non-editable-version state plus
  the documented release-note warning; the live review status reports no
  submission blockers.
- A fresh XcodeBuildMCP simulator regression on 2026-07-26 discovered 88 tests;
  64 passed, 0 failed, and 0 skipped. Its result bundle is
  `~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T23-41-37-995Z_pid12229_d3dcba8a.xcresult`.
- A later verification attempt rebuilt the test products successfully but timed
  out during simulator execution with Xcode's `DebuggerLLDB` version-store
  error. It is not counted as a pass or failure and does not replace the
  earlier completed 64-test result. A follow-up run with the simulator frontend
  open and one worker passed the current unit-test target 60/60 and UI-test
  target 4/4 (0 failed, 0 skipped) on the iPhone 17 Pro simulator.
- A fresh direct unit-test run on 2026-07-26 passed 60/60 tests, 0 failed, and
  0 skipped on `LANImageUploader iPhone 17 Pro` (iOS 26.5). Result bundle:
  `/tmp/lensbridge-current-unit.JjbNYj/tests.xcresult`.
- A fresh direct UI-test run on 2026-07-26 passed 4/4 tests, 0 failed, and
  0 skipped on the same simulator. Result bundle:
  `/tmp/lensbridge-current-ui.ULvi4Y/tests.xcresult`.
- Xcode's target build setting is now `INFOPLIST_KEY_CFBundleDisplayName=LensBridge`
  for Debug and Release, changed through Xcode's project UI. Build 49 also used
  an explicit archive override and the generated app bundle was verified as
  `CFBundleDisplayName=LensBridge`.
- Bundle ID: `com.janhagenclausen.LANImageUploader`
- Current App Store version: `1.58`, state `WAITING_FOR_REVIEW`
- Current combined review submission: `89637b5b-168b-4394-a34c-3a3f93dec9e2`,
  state `WAITING_FOR_REVIEW`, submitted with build `65` on 2026-08-05. It
  contains both the app version and `Full App Unlock`; do not cancel or edit it
  while Apple is reviewing it.
- Current IAP state: `Full App Unlock` (`6769515889`) is `WAITING_FOR_REVIEW`,
  not `READY_TO_SUBMIT`.
- Post-submission ASC audit on 2026-07-26 reports no review blockers. The CLI
  validator's single blocking check is the expected non-editable-version state
  while the submission is `WAITING_FOR_REVIEW`; the two remaining warnings are
  empty `whatsNew` fields for `en-US` and `da`.
- Latest valid uploaded production candidate: `1.58 (65)` (`7d58096f-cd10-478e-a974-051c0eac5f89`), attached to version `1.58`. The latest TestFlight validation build remains `1.57 (64)` (`1ca50bac-0890-4e5d-a3de-9d1a802b6a88`).
- Build `45` predates the final Settings `Test Connection` hardening made in this
  working tree; it was superseded by the historical valid build `55`.
- A local Release archive/export was completed as build `47` on 2026-07-25 using
  the explicit `LensBridge` display-name override. Its local signature was
  development-only (`get-task-allow=true`), so it is a diagnostic artifact and
  must not be uploaded to App Store Connect.
- A signed App Store Release archive and IPA were completed as build `50` on
  2026-07-25 after the macOS Keychain partition-list authorization. The IPA
  reports version `1.57`, `CFBundleDisplayName=LensBridge`,
  `ITSAppUsesNonExemptEncryption=false`, `get-task-allow=false`, an embedded
  `AMSMB2.framework`, and the target `PrivacyInfo.xcprivacy`. Local
  `codesign --verify --deep --strict` validation passed. The IPA was uploaded
  to App Store Connect and processing completed as `VALID`; it is attached to
  App Store version `1.57`.
- Build `52` was an earlier release candidate after the Settings state fix and
  public privacy-link correction. It remains valid in ASC but has been superseded
  by build `55`.
- Build `53` was the intermediate release candidate containing the PDF-generation
  main-thread fix. It remains valid in ASC but has been superseded by build `55`.
- Build `54` was the previous release candidate. It includes the final PDF-generation
  main-thread fix and force-unwrap hardening for keychain access, background-task
  dispatch, file-directory resolution, and user-facing URLs. It was exported with
  the manual App Store profile, locally verified (`get-task-allow=false`, strict
  codesign, privacy manifest present, and no `Premium override` string), uploaded,
  processed as `VALID`, and later superseded by build `55`.
- Build `55` was a historical production release candidate. It includes the retake queue
  replacement fix, background JPEG encoding, asynchronous archive previews, and
  serialized large-batch uploads. It was exported from an unsigned archive with
  the manual App Store profile, locally verified (`get-task-allow=false`, strict
  codesign, privacy manifest present, and no `Premium override` string), uploaded,
  processed as `VALID`, and was later superseded by build `57`.
- Build `56` was the previous TestFlight validation build. It contains the same
  scanner/gallery reliability changes plus the TestFlight-only
  `TESTFLIGHT_BUILD` compilation condition. Its local IPA was verified as
  `LensBridge`, version `1.57 (56)`, strict codesign valid, `get-task-allow=false`,
  and with the `Premium override` control present. It was uploaded and processed
  as `VALID` in ASC but is not attached as the production App Store candidate.
- Build `58` was a historical TestFlight validation build. It was archived with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS=TESTFLIGHT_BUILD`, exported and signed,
  and uploaded as `VALID` (`94ac5e48-761d-4ef3-a696-d4ad78376397`). The local IPA
  reports `LensBridge`, version `1.57 (58)`, strict codesign valid, and contains
  the `Premium override` control. It has been superseded by build 59.
- Build `59` was the later historical TestFlight validation build after Gallery/AppData
  cancellation and deletion-integrity hardening. It was archived with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS=TESTFLIGHT_BUILD`, exported and locally
  verified as LensBridge 1.57 (59), privacy manifest present, strict codesign
  valid, and Premium override present. It was uploaded and processed as
  `VALID` (`590fdab8-f631-4d5b-9df8-0804b5f560e4`). It is intentionally not
  attached to the production App Store version because TestFlight-only controls
  must not enter the submitted production binary.
- The en-US `APP_IPHONE_67` screenshot set was refreshed after visual review on
  2026-07-25. Screenshot 03 was regenerated from a current empty Settings
  capture, replacing an obsolete personal footer. ASC reports all three uploaded screenshots as
  `COMPLETE` at 1320×2868; the Danish localization still has no screenshot set.
- Build `57` was the previous production App Store candidate. It was archived
  from the checked-in Xcode target version without `TESTFLIGHT_BUILD`, exported
  with the manual App Store profile, and locally verified as `LensBridge`,
  version `1.57 (57)`, strict codesign valid, `get-task-allow=false`, and with
  `Premium override` absent. It was uploaded, processed as `VALID`, and attached
  to version `1.57` and has been superseded by build 61.
- Build `60` was an earlier production candidate from the post-hardening source.
  It was archived without `TESTFLIGHT_BUILD`, exported and locally verified as
  LensBridge 1.57 (60), privacy manifest present, strict codesign valid,
  `ITSAppUsesNonExemptEncryption=false`, and Premium override absent. It was
  uploaded and processed as `VALID` (`d485456f-6a25-420b-a530-11729f8a4a92`),
  It remains valid but is superseded by build 61 and was not attached to version
  1.57 because physical testing and owner-only ASC gates were incomplete.
- Build `61` was the later historical production candidate after the retake and archive
  deletion-integrity hardening. It was archived without `TESTFLIGHT_BUILD`,
  exported and locally verified as LensBridge 1.57 (61), with the privacy
  manifest present, strict codesign valid, and Premium override absent. It was
  uploaded and processed as `VALID` (`f41010b0-64e2-4d95-8d20-87fb7496edfb`),
  It was attached to version 1.57 as an earlier production candidate, but has
  been superseded by build 63, and subsequently by build 65. It is retained only
  as historical ASC evidence.
- Build `62` was a matching historical TestFlight validation build. It was archived
  with `TESTFLIGHT_BUILD`, locally verified as LensBridge 1.57 (62), with the
  privacy manifest present, strict codesign valid, and Premium override present.
  It was uploaded and processed as `VALID`
  (`5c226e61-21a3-462b-a164-1a8245307fd9`) and has now been superseded by build
  64.
- Build `63` was the production candidate after the sequence-aware Vision
  detector change. It was archived without `TESTFLIGHT_BUILD`, exported and
  locally verified as LensBridge 1.57 (63), with the privacy manifest present,
  strict codesign valid, `ITSAppUsesNonExemptEncryption=false`, and Premium
  override absent. It was uploaded and processed as `VALID`
  (`59950bb9-4571-40ba-8723-c6665d64e6a0`) and was attached to version 1.57.
- Build `64` is the latest TestFlight validation build for the 1.57 release line. It was archived
  with `TESTFLIGHT_BUILD`, locally verified as LensBridge 1.57 (64), with the
  privacy manifest present, strict codesign valid, and Premium override present.
  It was uploaded and processed as `VALID`
  (`1ca50bac-0890-4e5d-a3de-9d1a802b6a88`). Its `en-US` TestFlight “What to
  Test” notes now explicitly cover capture, scanning, Gallery/PDF, SMB testing,
  and the production/TestFlight Premium override distinction.
- Build `65` is the current production candidate for App Review guideline 3.1.1.
  It includes a visible `Restore Purchases` control that calls `AppStore.sync()`
  and then verifies the `Full App Unlock` entitlement. It was exported with the
  App Store profile, locally verified with strict signing and the privacy manifest,
  uploaded as `VALID` (`7d58096f-cd10-478e-a974-051c0eac5f89`), and attached to
  version `1.58` in the combined app and IAP submission.
- The app target's checked-in `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
  are `1.58` and `65` respectively for both Debug and Release. Test targets
  retain their existing build settings.
- Repository baseline at the start of this work: clean `main`, current merge `d26ae29`
- Simulator baseline: `LANImageUploader iPhone 17 Pro`, iOS 26.5
- Baseline build/run: passed
- Release-candidate simulator tests: 62 passed, 0 failed, 0 skipped out of 86
  discovered. The suite includes the retake filename-collision regression, the
  100-page sequential-PDF regression, the
  auto-capture page-gate regression, onboarding/privacy smoke coverage, and the
  Settings connection-test UI path, plus scanner orientation and preview-mapping
  regression coverage. It also verifies that a retake replaces the old queue
  entry instead of leaving a hidden duplicate, and that failed PDF page
  rendering removes partial output files.
  The build-55-named simulator run used `CURRENT_PROJECT_VERSION=55`; its
  xcresult is
  `~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T20-13-43-264Z_pid67720_c8fb327f.xcresult`.
- The post-change build-56-named simulator run also passed 62/0/0 out of 86;
  its xcresult is
  `~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T20-27-24-935Z_pid72509_96574bd5.xcresult`.
- The current post-change simulator run, using `CURRENT_PROJECT_VERSION=57`,
  passed 62/0/0 out of 86 and includes
  `generatedPDFHandles100SequentialPagesWithoutDroppingPages()`. Its xcresult is
  `~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T20-53-14-321Z_pid45093_6e4462ab.xcresult`.
- The latest scanner/PDF lifecycle change, including the sequence-aware Vision
  detector, was verified with another full XcodeBuildMCP simulator run: 64
  passed, 0 failed, 0 skipped out of 88 discovered. It covers the 100-page PDF
  regression, cancelled-PDF cleanup, failed local-delete preservation, explicit
  JPEG/PDF cancellation propagation, camera session start/stop guard, and the
  premium/TestFlight behavior. Result:
  `~/Library/Developer/XcodeBuildMCP/workspaces/LANImageUploader-355ffff5e016/result-bundles/test_sim_2026-07-25T22-58-19-517Z_pid45063_9387a258.xcresult`.
- A fresh idle memgraph from the updated simulator process reported 0 leaks / 0
  bytes. This updates the idle baseline only; it does not close the physical
  50/100-page Instruments gate. The capture and summary are under
  `/tmp/lensbridge-memgraph.aLiirT/`.
- A second memgraph captured while the current simulator process was on the
  document-scanner screen also reported 0 leaks / 0 bytes. This is scanner-screen
  lifecycle evidence, not physical-camera or sustained page-batch evidence. The
  capture and summary are under `/tmp/lensbridge-scanner-memgraph.hxUuE4/`.
- A fresh idle memgraph captured after the current UI-test run on 2026-07-26
  reported `0 leaks / 0 bytes`. This is current simulator idle evidence, not a
  substitute for the real-device 50/100-page scanner stress gate. The capture
  and summary are under `/tmp/lensbridge-memgraph.0EkMoK/`.
- Meaningful UI smoke coverage is now present and passes on the simulator: Home
  entry points, onboarding privacy boundary, launch foreground state, and launch
  performance. Physical camera/SMB behavior is still outside simulator coverage.
- A current semantic UI snapshot also verified the release-facing navigation:
  Home exposes labeled Capture Image, Scan Documents, Gallery, Upload, Archives,
  and Settings targets; Settings exposes the server fields, `Test Connection`,
  and Help; Help Center exposes Quick Start and the Photos & Scanner,
  Gallery & PDF, Upload & Server, and Archive & Files topics. The environment
  has no separate `accessibility_audit.py` tool installed, so this is semantic
  UI smoke evidence rather than a WCAG certification.
- App Store Connect availability is now initialized through the official API:
  ASC reports 175/175 territory availabilities as `available=true` and
  `availableInNewTerritories=true`. The availability gate is green. The app
  version and IAP are now in the combined `WAITING_FOR_REVIEW` submission.
- Screenshot set `be57d8d3-9191-4a0f-a095-3ac9a6908e3b` contains three `COMPLETE`
  iPhone screenshots at 1320x2868; local validation reports zero errors and zero
  warnings. The App Store Connect app record exposes a 1024x1024 `APP_STORE`
  icon.
- App Store Connect now contains both `en-US` and `da` localizations for app-info
  and version metadata. The Danish description, keywords, promotional text, and
  support URL were applied successfully; the canonical files are under
  `docs/app-store-metadata/`. A fresh API attempt on 2026-07-26 was rejected for
  both locales with `Attribute 'whatsNew' cannot be edited at this time`; the
  release-note values remain local-only while version 1.58 is locked in review.
- `asc metadata validate --dir docs/app-store-metadata` is clean (4 files,
  0 errors, 0 warnings). The current strict ASC validation still reports the
  two web-only release-note fields, the non-editable state of the active review
  version, and one informational App Privacy publication check.
- The configured ASC support URL still points to the public GitHub repository,
  but the public `main` README is the older ImageDrop/photo-only description;
  the release-facing `README.md`, `PRIVACY.md`, and `THIRD-PARTY-NOTICES.md` in
  this worktree are not public until the owner reviews and publishes them. Do
  not submit while the support surface materially contradicts LensBridge's
  current scanning/PDF behavior.
- Root-level `PrivacyInfo.xcprivacy` is included in the app target with
  the UserDefaults required-reason declaration. It was added through Xcode's
  target-membership UI, and the final IPA contains the manifest at the app bundle
  root. The declaration follows Apple's
  [privacy manifest guidance](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
  and [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- The prior development-signed IPA's app and embedded `AMSMB2.framework`
  signatures passed local `codesign --verify --deep --strict` checks. Apple
  server-side validation remains a separate gate because the local ASC key is
  not copied into altool's expected private-key directory.
- The simulator build and full test suite now complete with no warnings or errors.
  Retake JPEG encoding is offloaded from the main actor, archive thumbnails and
  fullscreen previews load local files asynchronously with bounded dimensions,
  and multi-file uploads are deliberately serialized so large scan batches do
  not retain one full `Data` buffer per concurrent upload. Gallery JPEG/PDF
  preparation is cancellable and cleans generated temporary files; local
  deletion only commits metadata/UI removal after the file operation succeeds.
  The TestFlight-only premium override is gated by the deterministic build
  channel written by `ci_scripts/ci_pre_xcodebuild.sh`. The exact external-beta
  workflow writes `.testFlight`; all other Cloud actions write `.production`.
  Gallery PDF
  generation now has explicit cancellation propagation from the SwiftUI task to
  the detached page renderer, with partial-output cleanup retained in the PDF
  service.
- The 2026-07-26 revision hardens retake replacement and archived-image deletion:
  a failed old-file removal keeps the original Gallery queue entry authoritative
  and cleans up the newly written retake on a best-effort basis; archived-image
  deletion now keeps failed items selected and reports partial failure instead of
  claiming that every selected item was deleted. Archive restore now removes a
  destination only when it is known to exist, so a missing destination does not
  mask the copy operation.
- After this revision, the full XcodeBuildMCP simulator suite passed 64 tests,
  with 0 failures and 0 skips out of 88 discovered, with no reported warnings
  or errors. The result bundle is recorded in the scanner test matrix.
- Reproducible build gates:
  - App Store archive: run `ci_scripts/ci_pre_xcodebuild.sh` without the exact
    external-beta workflow identity, which writes `.production`.
  - TestFlight archive: the exact workflow ID
    `37c9d62c-448d-4f60-8672-496a5c044c34` and name
    `TestFlight - external beta test` write `.testFlight` automatically.
  - Verify the script behavior from controlled temporary inputs with
    `scripts/test_xcode_cloud_distribution_gate.sh` before release work.
  - `scripts/release_preflight.sh` verifies the extracted IPA's deterministic
    Info.plist marker: absent for production and
    `external-testflight-v1` for TestFlight.
- App Store Connect age-rating declaration is present with no declared medical,
  sexual, violent, gambling, messaging, or advertising content. The project sets
  `ITSAppUsesNonExemptEncryption=false` and has no separate encryption declaration;
  export-compliance must still be confirmed for the AMSMB2/SMB dependency before
  the final submission.

## Availability and monetization decision

These are owner decisions, not technical defaults:

- **App availability** means the App Store countries/regions in which LensBridge
  may be downloaded. It is separate from local-network availability, SMB reachability,
  or whether a configured Windows server is online. The owner selected public
  distribution in all available markets, with automatic availability in new markets.
  The ASC record is initialized and verified: all 175 territories are available,
  and new Apple territories are enabled automatically. This is separate from
  local-network availability, SMB reachability, or whether a configured Windows
  server is online.

- **In-App Purchase (IAP)** is the StoreKit purchase already implemented in the app:
  LensBridge is free to try for 15 successful uploads of images or documents, after
  which the non-consumable `Full App Unlock` (`USD 1.99`) removes the limit. ASC
  reports it as `WAITING_FOR_REVIEW` in the combined submission with version 1.58.

The App Review contact record is configured for the active submission. The active
submission must not be canceled or edited while Apple is reviewing it.

## Product promise and boundaries

The app is a local-first capture and document workflow:

1. Capture clinical photos or scan paper documents into multi-page PDFs.
2. Keep the gallery and archives on the iPhone by default.
3. Export selected images or PDFs to an SMB share on the same local network.
4. Let the user's existing Windows-based journal system ingest files from its own
   watched/import folder.

The app does not itself provide an EHR, patient lookup, clinical decision support,
diagnosis, OCR-to-journal integration, cloud storage, backup, remote access, or a
guarantee that a specific journal system can ingest the exported filename. Those
requirements must be stated in onboarding, Help, store copy, and review notes.

## Gate 1: selected product name

The owner selected `LensBridge` with the subtitle `Private Photo & Scan Transfer`.
The name is now applied to the App Store Connect app record, English and Danish
metadata, the in-app visible branding, release copy, and the local screenshot
drafts. The bundle identifier remains unchanged.

The earlier exact-title search was only an App Store availability signal, not
trademark clearance or a reservation. Before submission, perform the final
trademark, domain, and Apple review check. The target display-name setting and
the build-57 IPA are both verified as `LensBridge`.

## Gate 2: scanner and PDF maturity audit

### Current code surfaces

- Capture/session lifecycle and Vision rectangle detection: `CameraPicker.swift`
- Capture-to-storage handoff: `CameraView.swift`, `AppData.swift`
- Normalized crop, perspective correction, and image rendering:
  `GalleryModels.swift`
- Gallery thumbnails/fullscreen/export: `GalleryItemView.swift`, `GalleryView.swift`
- Sequential PDF generation: `Services/PDFGenerationService.swift`
- Upload derivatives and SMB transfer: `GalleryView.swift`, `ImageUploadService.swift`

### External comparison set

Use these repositories as reference implementations, not copy sources:

- [`WeTransferArchive/WeScan`](https://github.com/WeTransferArchive/WeScan) for a
  mature rectangle-detection/cropping architecture (archived; inspect only with
  license and maintenance status in mind).
- [`StanDimitroff/DocumentScanner`](https://github.com/StanDimitroff/DocumentScanner)
  for a small `VNSequenceRequestHandler`-based detector with tunable confidence,
  size, aspect-ratio, and quadrature thresholds.
- [`edonv/DocumentScannerView`](https://github.com/edonv/DocumentScannerView) for a
  native SwiftUI/VisionKit wrapper shape.
- [`hardikdarji/swiftui-vision-scanner`](https://github.com/hardikdarji/swiftui-vision-scanner)
  for a compact SwiftUI auto-capture and multi-document reference flow.
- Apple/VisionKit integrations in active projects such as
  [`expo/expo`](https://github.com/expo/expo) and
  [`nextcloud/ios`](https://github.com/nextcloud/ios) for delegate, cancellation,
  and lifecycle handling.

The GitHub connector search also surfaced `sane-apps/SaneScan`, `RodenPaul86/DocMatic`,
and `s4rv4d/docWind-iOS` as second-pass candidates for large-document UX and
VisionKit integration. They should be inspected only after checking their current
license, maintenance activity, and whether the relevant code is reusable; this
repo should borrow design lessons, not copy implementation wholesale.

### Reproducible reference review snapshot

The following read-only GitHub API review was performed on 2026-07-26. The refs
are recorded so a future release audit can tell whether a recommendation still
matches the upstream code. No source code was copied into LensBridge.

| Repository and ref | License / status | Relevant lesson for LensBridge | Reuse decision |
| --- | --- | --- | --- |
| [WeScan](https://github.com/WeTransferArchive/WeScan), `861003ae` | MIT; archived | `VisionRectangleDetector` makes confidence, maximum observations, aspect ratio, and “largest quadrilateral” selection explicit. | Use as a detector-threshold comparison only; do not adopt the archived controller wholesale. |
| [DocumentScanner](https://github.com/StanDimitroff/DocumentScanner), `74eef85f` | GPL-3.0; last upstream commit is older | `VNSequenceRequestHandler` plus configurable size, confidence, quadrature-tolerance, and aspect-ratio limits is a useful experiment for temporal stability. | Do not copy GPL code. Benchmark the same ideas in LensBridge’s own implementation. |
| [DocumentScannerView](https://github.com/edonv/DocumentScannerView), `b2783148` | MIT; SwiftUI/VisionKit wrapper | Coordinator ownership, explicit cancel/failure delegate paths, and `VNDocumentCameraViewController.isSupported` are good lifecycle checks. | Reuse the design lesson; LensBridge keeps its custom camera flow and local Gallery contract. |
| [swiftui-vision-scanner](https://github.com/hardikdarji/swiftui-vision-scanner), `3b8a2736` | No license declared in the repository snapshot | Compact SwiftUI camera/overlay/PDF separation is useful for UX comparison. | No code reuse until a compatible license is declared. |
| [Expo](https://github.com/expo/expo), `e84410db` | MIT; actively maintained monorepo | Use only as a second-pass reference for native camera-module lifecycle and permission boundaries. | No dependency or code copy planned. |
| [Nextcloud iOS](https://github.com/nextcloud/ios), `bd6f12cf` | GPL-3.0; actively maintained | Useful for production-grade media lifecycle and cancellation/error UX, not scanner implementation. | Do not copy code; inspect behavior patterns only. |

The snapshot confirms two important guardrails: GPL/no-license projects are
reference-only, and the active implementation work should remain focused on
measurable behavior—detector stability, lifecycle cancellation, bounded image
decoding, and multi-page integrity—rather than a wholesale library swap.

### Required technical checks

The executable device protocol is documented in
[`docs/SCANNER-PHYSICAL-TEST-MATRIX.md`](SCANNER-PHYSICAL-TEST-MATRIX.md).

1. Make camera session setup and teardown idempotent across repeated presentation,
   backgrounding, interruptions, denied permission, and rotation.
2. Measure Vision work with Instruments and add explicit back-pressure/sequence
   handling so detection cannot outlive the view controller or pile up during load.
3. Compare the detected crop, visible preview crop, captured JPEG, Gallery thumbnail,
   PDF page, and upload derivative using the same test fixtures and coordinate system.
4. Exercise auto-capture with poor light, skew, partial pages, moving pages, glossy
   paper, portrait/landscape rotation, zoom changes, and page-to-page transitions.
5. Exercise 1, 10, 25, 50, and 100-page sessions. Record peak memory, time to first
   page, time to finish PDF, cancellation behavior, and whether the app returns to a
   usable state after failure.
6. Add a bounded preview/fullscreen rendering policy; never decode a full-resolution
   page merely to display a thumbnail or a list cell.
7. Add interruption, camera permission, low-storage, corrupt-file, cancellation,
   and partial-export tests. Preserve originals until the export/upload result is
   confirmed.
8. Run a physical-device matrix. The simulator cannot prove live edge alignment,
   camera focus/exposure behavior, thermal behavior, or real SMB connectivity.

### Prioritized findings from the comparison

- The small Vision-based reference scanners make detector thresholds explicit and
  keep crop validation separate from UI rendering. This repo now has the same
  separation in `DocumentCaptureQuality` and `DocumentCrop`; the remaining work is
  to tune thresholds with real-device fixtures rather than guess from simulator
  frames.
- Sequence-aware Vision processing is now used by the live rectangle detector via
  `VNSequenceRequestHandler` on the serial detection queue, while
  `alwaysDiscardsLateVideoFrames` provides frame back-pressure. The handler is reset
  after orientation, mode, interruption, runtime-error, and presentation changes;
  real-device benchmarking is still required to tune whether the temporal context
  improves edge stability without increasing latency or memory use.
- Mature camera wrappers treat presentation/disappearance, permission denial, and
  delegate teardown as first-class lifecycle events. This pass made session setup
  idempotent, detaches the video delegate on disappearance, and preserves the
  post-capture page gate across temporary edge-loss.
- SwiftUI wrappers and active app integrations consistently keep scan review and
  persistence outside the camera controller. This repo already saves accepted pages
  immediately to the local Gallery; the remaining physical test must verify that
  cancellation, interruption, and partial batches preserve that invariant.
- Large-document implementations process pages sequentially and bound preview
  decoding. This repo now has a 100-page PDF regression test and bounded Gallery
  rendering; fullscreen decoding runs away from the main actor and PDF page
  generation checks cancellation between pages. The 50/100-page memory matrix
  remains a device gate.

### Already addressed and still required

The merged scanner-memory/framing work already bounds Gallery thumbnails, serializes
batch export, saves compressed capture bytes, and reuses prepared upload files. This
pass additionally made scanner session setup idempotent across repeated appearance,
bounded Gallery fullscreen rendering to 2400 px off the main actor, made PDF
generation cancellation-aware between pages, and added a direct Settings route when
camera permission is denied. Camera session interruption and runtime-error recovery
now reports a user-facing state and reconnects only while the scanner remains visible.
Retake filenames now include a UUID suffix to prevent same-second overwrites, and
upload cancellation now cancels the active task, stops SMB progress, preserves an
explicit aborted status, and cancels before uploaded-file cleanup. The TestFlight
override uses the deterministic Xcode Cloud build channel; App Store production
actions resolve to `.production`.
The remaining release work is lifecycle stress, physical-device scanning, and evidence
from Instruments/MetricKit or an equivalent crash/performance surface. The sequence
handler change is covered by compilation and the full simulator suite, but a simulator
cannot exercise the camera frame stream or prove its temporal behavior.

## Gate 3: in-app onboarding and troubleshooting

The onboarding and Help Center now cover the workflow, scope, privacy boundary, and
troubleshooting. Settings also exposes an explicit `Test Connection` action. The
current implementation verifies SMB reachability, authentication, share access,
and target-directory access without writing a test file; a harmless test upload is
still a release-candidate decision because its deletion and journal-audit behavior
must be agreed with the target clinic workflow.
The owner's Notion setup guide was re-read on 2026-07-26. Its core prerequisites
(Windows/local server, watched import folder, same Wi-Fi/LAN, share name, target
directory, credentials, and journal-specific filename rules) are represented in
the current in-app onboarding and Help Center. The obsolete beta/TestFlight
instructions and the old DermaSnap branding are intentionally not copied into the
public release UI.

The setup flow must:

1. Confirm the workflow: local iPhone capture -> local SMB share -> existing journal
   import/watch folder.
2. Explain what the user's journal system must support before setup begins.
3. Collect/validate server IP or host, share name, target directory, username, and
   password, with Keychain disclosure and no credential logging.
4. Provide `Test connection` directly in the Server Connection section and
   distinguish network reachability, authentication,
   share access, target-directory access, and journal-ingest failures.
5. If a harmless test upload is later added, use a clearly marked test filename and
   explain how to remove it; never imply that upload success means journal ingestion
   succeeded.
6. Show a final checklist and a link to the offline Help Center.

Troubleshooting should be organized as a decision tree:

- Camera permission / no camera / blurry or misaligned scan
- Auto-capture never triggers or triggers too early
- Page order, crop, rotation, PDF size, and failed export
- Local Network permission and Wi-Fi/VPN isolation
- Host/IP, share, target directory, username/password, and SMB port
- Upload timeout, duplicate filename, partial batch, and retry
- Journal system did not ingest the file
- Low storage, app restart, and recovery of local Gallery/Archive data

Every article must say whether the fix is in the app, on the iPhone network, on the
Windows server, or in the journal system.

## Gate 4: App Store and legal/review readiness

Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
require particular care for health-related apps and privacy disclosures. The store
copy must describe the capture/file-transfer scope without implying diagnosis,
treatment, EHR integration, or guaranteed journal ingestion; confirm with the
owner's legal entity and privacy review before submission.

This is the pre-submission checklist; the current live state is recorded in the
baseline and owner/device sections below.

- Select one primary name and update branding only after Gate 1.
- Replace placeholder/empty App Store metadata in Danish and English as appropriate.
- Add a precise description, subtitle, keywords, support URL, privacy-policy URL,
  copyright, category, availability, and content-rights declaration.
- Complete age rating, App Privacy, export-compliance/encryption declaration, and
  review contact/demo notes.
- ASC currently reports age rating `FOUR_PLUS`, primary category `PHOTO_AND_VIDEO`,
  and secondary category `PRODUCTIVITY`. The local production `Info.plist` has
  `ITSAppUsesNonExemptEncryption=false`; `asc encryption declarations list`
  returns no declaration, which is consistent with the CLI's documented exempt-
  encryption path and still needs to be confirmed against the final submitted
  build in ASC.
- Complete the open-source compliance review for AMSMB2/libsmb2. The dependency
  is LGPL-2.1-or-later at the library layer; the project embeds AMSMB2 dynamically,
  and [`THIRD-PARTY-NOTICES.md`](../THIRD-PARTY-NOTICES.md) records the required
  license/source obligations for the final public support surface.
- Keep the live privacy URL on the existing public README until `PRIVACY.md` is
  published; switch it to the dedicated policy page before submission.
- The public GitHub `main` README was rechecked on 2026-07-25 and is still the
  older photo-only support text. The new local README, `PRIVACY.md`, third-party
  notices, and release documents are not public until this worktree is reviewed
  and published. Treat that publication/review as a mandatory support-surface gate
  before changing the ASC privacy or support URLs.
- Explain the SMB/Windows prerequisites and the explicit non-capabilities in the
  store description and review notes.
- App availability and price are verified in ASC: all 175 territories are enabled
  and the app price is free. The one-time `Full App Unlock` remains a separate
  non-consumable IAP that must be submitted with the app version.
- The three 6.9-inch promotional screenshots are uploaded and `COMPLETE` for the
  `en-US` localization (`360383c6-6b03-4e14-a1bd-185612055268`). The Danish
  localization (`5beff68a-5051-4404-8689-69e7e0ad19dd`) currently has no
  screenshot set; before submission, either upload a Danish-text variant or
  explicitly accept the English screenshot fallback after checking the storefront
  presentation.
- The required 13-inch iPad promotional screenshots are uploaded and `COMPLETE`
  for the same `en-US` localization using `APP_IPAD_PRO_3GEN_129`. The assets
  are 2064×2752 PNGs in `docs/app-store-screenshots/asc-ipad-13/en-US/` and
  belong to ASC screenshot set `faceeb45-fca3-4723-8b2c-1b9c77dd44ee`.
- The active submission already has processed build `65` attached to version
  `1.58`; any replacement build must use a higher, unused build number.
- Use screenshots that show the real workflow: Home, photo capture, document scan,
  Gallery/PDF, Server Connection, and a clear local-only/privacy message. Do not put
  CPR numbers, patient data, real server addresses, usernames, or credentials in
  screenshots.
- Confirm the uploaded production build exposes the approved 1024×1024 `APP_STORE`
  icon; build 65 currently exposes that icon in ASC and the source AppIcon assets
  are validated locally.
- Re-run `asc validate` until there are no blocking errors. Warnings must be reviewed,
  not blindly ignored.

## Owner/device gates remaining

The following items remain open; the active ASC submission must not be altered
while Apple is reviewing it:

1. **App Review Information is configured** for the current submission. Keep the
   configured owner contact details unchanged while Apple reviews version 1.58.
2. The localized release notes are present in
   `docs/app-store-metadata/version/1.58/{en-US,da}.json`, but ASC still reports
   both `whatsNew` fields empty. The version is locked in review, so do not
   cancel the active submission merely to change this non-blocking warning;
   enter them in the next editable version or after review if ASC permits it.
3. `Full App Unlock` has been submitted together with version 1.58 and is now
   `WAITING_FOR_REVIEW`.
4. Run `docs/SCANNER-PHYSICAL-TEST-MATRIX.md` on a real iPhone against the actual
   Windows/SMB/journal workflow, including 1/10/25/50/100-page batches,
   interruption/recovery, low-storage behavior, and ingest verification.
   The configured physical test device currently reports as disconnected and
   unavailable, so no physical-device result is claimed here.
5. Publish and review the local `README.md`, `PRIVACY.md`, and
   `THIRD-PARTY-NOTICES.md` before changing the live ASC support/privacy URLs or
   before the next metadata update. The live ASC support URL currently points
   to the GitHub repository root, whose public README still contains the old
   ImageDrop branding and an iOS 18 requirement; the corrected local release
   documents are not public until an owner-approved commit/publish step. The
   current submission must not be altered while it is under review.
6. After Apple approval, release version 1.58 manually because the ASC release
   type is `MANUAL`; approval alone will not make the app publicly available.

### Exact ASC operator checklist

Use the following values as the release record. The app and IAP are already
submitted; do not create a second submission while the current one is active.

1. **App Review Information**
   - Use the already configured App Review contact in ASC. Do not copy personal
     contact details into the repository or release notes.
   - Demo account required: No. The reviewer can exercise capture, scanning,
     Gallery, archive, and PDF generation without a server. SMB upload requires
     a reachable test share and credentials supplied by the owner if Apple asks
     for that path.
   - Review notes: use the text in the **App Review notes draft** section of
     `docs/app-store-copy-draft.md`.
2. **Version 1.58 release notes**
   - English: `Adds a Restore Purchases control for Full App Unlock, plus ongoing reliability improvements for scanning, Gallery, PDF, and SMB workflows.`
   - Danish: `Tilføjer Gendan køb til Full App Unlock samt fortsatte stabilitetsforbedringer af scanning, Galleri, PDF og SMB-arbejdsgange.`
3. **In-App Purchase**
   - `Full App Unlock` was submitted together with version 1.58 and currently
     reports `WAITING_FOR_REVIEW`.
4. **Privacy and export compliance**
   - Publish the existing App Privacy declaration and verify it matches the
     local-only behavior (no cloud sync, analytics, or advertising tracking).
   - Confirm the export-compliance answer for the app and AMSMB2 dependency;
     the production IPA currently declares `ITSAppUsesNonExemptEncryption=false`.
5. **Current submission**
   - Version 1.58 is attached to processed build 65 and the combined app + IAP
     submission is already `WAITING_FOR_REVIEW`. Do not create a second
     submission or cancel the active one.

### Final archive procedure

After the name, privacy-manifest target membership, physical-device gate, and ASC
owner fields are complete, use a new build number greater than the last uploaded
build:

```sh
  asc xcode archive \
  --project LANImageUploader.xcodeproj \
  --scheme LANImageUploader \
  --configuration Release \
  --archive-path .asc/artifacts/LANImageUploader-unsigned-66-appstore.xcarchive \
  --clean \
  --xcodebuild-flag=-destination \
  --xcodebuild-flag=generic/platform=iOS \
  --xcodebuild-flag=INFOPLIST_KEY_CFBundleDisplayName=LensBridge \
  --xcodebuild-flag=CURRENT_PROJECT_VERSION=66 \
  --xcodebuild-flag=CODE_SIGNING_ALLOWED=NO \
  --xcodebuild-flag=CODE_SIGNING_REQUIRED=NO

asc xcode export \
  --archive-path .asc/artifacts/LANImageUploader-unsigned-66-appstore.xcarchive \
  --export-options docs/ExportOptions-AppStore.plist \
  --ipa-path .asc/artifacts/LensBridge-1.58-66-appstore.ipa

unzip -l .asc/artifacts/LensBridge-1.58-66-appstore.ipa | grep 'Payload/.app/PrivacyInfo.xcprivacy'
VERIFY_DIR=$(mktemp -d)
unzip -q .asc/artifacts/LensBridge-1.58-66-appstore.ipa -d "$VERIFY_DIR"
APP_PATH=$(find "$VERIFY_DIR/Payload" -maxdepth 1 -name '*.app' -print -quit)
scripts/verify_build_channel_marker.sh "$APP_PATH" production
asc builds upload --app 6742799620 --ipa .asc/artifacts/LensBridge-1.58-66-appstore.ipa --platform IOS --wait
```

The build number is an example only; use the next unused number at archive time.
Inspect the IPA before uploading, then attach the processed replacement build to version 1.58
and run `asc validate --strict` again.

## Exit criteria

The goal is complete only when all of these are true:

- A chosen name is consistently implemented and reserved/accepted by Apple.
- Scanner and PDF flows pass the physical-device stress matrix.
- No known crash, memory-growth, lifecycle, data-loss, or upload-integrity defect
  remains without an explicit documented limitation.
- Meaningful UI smoke tests run instead of being skipped.
- Onboarding, Help, troubleshooting, privacy, and store copy agree with the actual
  behavior.
- The final build is processed and attached to the App Store version.
- `asc validate --strict` is clean or every remaining warning is intentionally
  documented and non-blocking.
- The submission is ready for the owner's final Apple review/submit decision.
