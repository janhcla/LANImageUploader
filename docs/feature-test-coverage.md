# ImageDrop Feature Test Coverage

This note records the app features, the expected behavior, and the tests that cover them.

## App Lifecycle And Navigation

- Launch shows the custom launch screen, then routes to onboarding until `onboardingCompleted` is true.
- Onboarding walks through welcome, feature summary, settings, tutorial, help guide, and completion.
- Home provides entry points for Capture, Gallery, Upload, Settings, and Archives.
- Settings shows a badge on Home until the core server settings and password are present.
- Covered by UI launch smoke tests and unit coverage for `AppData` initialization and settings persistence state.

## Capture

- Capture starts from `CameraView` and presents the camera.
- A successful capture is saved under `Documents/images` as `IMG_yyyyMMdd_HHmmss.jpg`.
- The saved file is appended to the in-memory gallery with the `.jpg` suffix removed from the display name.
- A save failure shows an error and does not append a gallery item.
- Covered by `cameraSaveImageAppendsGalleryItem` and `cameraSaveImageFailureDoesNotAppendGalleryItem`.

## Gallery

- Empty gallery shows an empty state.
- A normal image tap opens a fullscreen preview when image data can be read.
- Select mode toggles image selection.
- Single delete removes the local file and gallery item.
- Multi-select delete removes selected files and clears selection.
- Single rename updates the display name, defaulting to `Image` when the new name is empty.
- Batch rename applies the user prefix plus a two-digit sequence in gallery order.
- Archive All saves gallery images into today's archive without removing them from the queue.
- Batch Upload renames selected images and navigates to Upload.
- Covered by AppData delete/archive tests and direct gallery behavior tests.

## Naming And OCR

- Naming sheet writes through `appData.imageName`.
- The clear button empties the current name.
- OCR modes are Full, Numbers, and CPR.
- Full OCR accepts non-empty text longer than one character.
- Numbers OCR extracts digits and rejects text with no digits.
- CPR OCR accepts dashed CPR text and normalizes exactly ten digits to `DDMMYY-XXXX`.
- Covered by `TextValidationTests`.

## Upload

- Upload initializes one idle status per queued image.
- Start Upload is blocked when the trial is exhausted and opens Full App Unlock.
- Upload requires server IP, share name, username, and a stored password.
- Missing passwords and actionable upload failures surface a settings action.
- Successful uploads update progress, mark success, and consume one trial upload unless Full App Unlock is active.
- Failed uploads do not consume trial uploads.
- Duplicate server files show a Rename/Overwrite prompt; overwrite retries with `overwrite: true`.
- Retry Failed only retries failed images.
- Abort marks active uploads as failed.
- When all uploads succeed, the queue can be cleared and local files are deleted.
- Covered by premium access tests, mock upload service behavior tests, and upload failure-detail tests.

## Premium

- Trial starts with 15 successful uploads.
- Each successful upload consumes one trial upload.
- Trial exhaustion blocks new uploads.
- Developer Mode temporarily unlocks the full app but does not mark a purchase.
- Purchased Full App Unlock persists independently of Developer Mode.
- Covered by `premiumTrialStartsWithFifteenUploads`, successful-upload counting, exhaustion, developer mode, and purchased unlock tests.

## Settings And Discovery

- First setup collects target directory, username, password, optional port, OCR mode, premium controls, and discovery/manual setup entry points.
- Manual setup collects server IP, share, target directory, optional port, username, and password.
- Save persists `ServerSettings` and the password.
- Reset clears fields and returns to first setup.
- Discovery reports granular `ConnectionStatus` updates.
- Covered by connection status/error tests, mock discovery tests, and settings-related AppData tests.

## Archives

- File archives are stored in `Documents/YYYY-MM-DD`.
- Archive listing only includes date folders matching `YYYY-MM-DD`, newest first.
- Archive rows can be opened, renamed locally, selected, restored, and deleted.
- Restoring archives copies files back into `Documents/images`, skips duplicates already in the gallery, and appends restored images once.
- Deleting archives removes custom names for deleted dates.
- Archived image detail supports fullscreen preview, Restore All, selected restore, selected delete, and removing an empty archive folder after deleting its final image.
- Covered by AppData archive tests and local file/archive service tests.

## Local File Storage

- Image saves create the `images` folder before writing.
- Archive saves create the date folder, copy missing files, and count existing files.
- Archive reads ignore non-image files for image lists and ignore non-date folders for archive dates.
- Covered by mock file-service tests and service-facing AppData archive tests.

## Network And SMB

- Network discovery can use direct IP, Bonjour, and subnet discovery.
- Upload uses AMSMB2, connects to the configured share, checks duplicates before writing, verifies target directory existence, writes JPEG data, reports progress, and disconnects.
- Upload errors are mapped to user-facing reasons, guidance, and settings actions where useful.
- Covered by connection status/error tests and upload error detail tests. Real SMB transfer remains an integration scenario requiring an SMB server.
