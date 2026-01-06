# Spec: Refactor Architecture - Extract Logic to Services

## Overview
This track focuses on improving the application's architecture by addressing MVVM violations and the "Massive View Model" pattern. Specifically, it involves extracting file system management and SMB network logic out of the Views (`UploadView`, `GalleryView`) and the central `AppData` class into dedicated, single-purpose service classes.

## Objectives
- **Decouple UI from Logic:** Remove raw SMB connection and file I/O logic from SwiftUI Views.
- **Slim Down AppData:** Reduce the complexity of `AppData` by delegating data persistence and transfer tasks to services.
- **Improve Maintainability:** Create a clear separation of concerns, making the codebase easier to navigate and refactor in the future.

## Functional Requirements
- **ImageUploadService:**
    - Extract the `uploadImage` logic from `UploadView`.
    - Provide a clean interface for uploading a `CapturedImage` to a configured SMB share.
    - Handle SMB connection, authentication, and error mapping within the service.
- **FileService:**
    - Extract file management logic (Saving, Archiving, Deletion, and Retrieval) from `AppData` and `GalleryView`.
    - Provide methods for:
        - Saving captured images to the temporary storage.
        - Archiving images to dated folders (`saveImagesToDatedFolder`).
        - Deleting individual and batch images.
        - Fetching/listing archived images.

## Non-Functional Requirements
- **Architecture:** Follow the Service Pattern to isolate side effects (I/O and Networking).
- **Readability:** Ensure service interfaces are clear and use Swift concurrency (`async/await`) properly.

## Acceptance Criteria
- `UploadView` no longer contains `AMSMB2` or `SMB2Manager` initialization logic.
- `GalleryView` no longer performs direct `FileManager` operations.
- `AppData` delegates its file-related methods to the new `FileService`.
- The app remains fully functional (capturing, archiving, and uploading work as before).

## Out of Scope
- Writing unit tests (deferred to a later track).
- Addressing Issue #2 (Blocking I/O), #3 (Dependency Injection), #4 (Constants), or #5 (Typed Errors) specifically, though the refactoring may naturally touch upon them.
