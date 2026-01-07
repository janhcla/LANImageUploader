# Spec: Fix Blocking I/O

## Overview
This track addresses Issue #2 from the initial code assessment: "Fix Blocking I/O". Currently, many file system operations (saving, archiving, deleting) are performed synchronously on the Main Actor, which can lead to UI freezes when processing large batches of images. This track aims to offload these operations to a dedicated background actor to ensure a smooth user experience.

## Objectives
- **Offload Heavy I/O:** Move all long-running or batch file operations off the Main Actor.
- **Asynchronous API:** Standardize the `FileServiceProtocol` to use asynchronous methods for all I/O tasks.
- **UI Responsiveness:** Ensure the UI remains responsive during background tasks (e.g., show progress or spinners where appropriate).

## Functional Requirements
- **`FileActor`:**
    - Implement a new `FileActor` (Swift Actor) to encapsulate the actual `FileManager` calls.
    - Actors provide built-in synchronization and offload work to a background thread pool.
- **`FileService` Refactoring:**
    - Update `FileService` to delegate heavy work to `FileActor`.
    - Change `archiveImages`, `removeItem`, and `saveImage` to be `async` in both the protocol and implementation.
- **AppData and View Updates:**
    - Update `AppData.saveImagesToDatedFolder` to handle the new `async` call.
    - Update `GalleryView` and `ArchiveView` to use `Task { await ... }` for file operations.
    - Ensure that UI-dependent state updates (like `scanStatus`) still happen on the Main Actor.

## Non-Functional Requirements
- **Performance:** Significant reduction in Main Actor blocking during multi-image operations.
- **Safety:** Use Swift Concurrency (`async/await`, `actors`) to prevent data races.

## Acceptance Criteria
- All file I/O methods in `FileService` are asynchronous.
- The UI remains interactive (scrollable, responsive buttons) while archiving 10+ images.
- The app builds and runs without errors.

## Out of Scope
- Implementing Issue #5 (Typed Error Handling) fully, though I/O errors will be handled as before.
- Changing the SMB networking logic (which is already asynchronous).
