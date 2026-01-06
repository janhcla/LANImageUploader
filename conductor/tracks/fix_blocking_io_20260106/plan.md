# Plan: Fix Blocking I/O

## Phase 1: Background Actor Implementation [checkpoint: 3df87c3]
- [x] Task: Create `LANImageUploader/Services/FileActor.swift` to handle low-level I/O on a background thread. [ab44b56]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Background Actor Implementation' (Protocol in workflow.md)

## Phase 2: Refactor FileService for Asynchronous Operations [checkpoint: a3d5bf6]
- [x] Task: Update `FileServiceProtocol` to make heavy I/O methods `async`. [7b9e10d]
- [x] Task: Update `FileService` implementation to use `FileActor` for archiving, saving, and deleting. [7b9e10d]
- [x] Task: Conductor - User Manual Verification 'Phase 2: Refactor FileService for Asynchronous Operations' (Protocol in workflow.md)

## Phase 3: Update UI and AppState for Async I/O [checkpoint: de8df19]
- [x] Task: Refactor `AppData.saveImagesToDatedFolder` to use `await`. [7b9e10d]
- [x] Task: Update `GalleryView` and `ArchiveView` to wrap file operations in asynchronous `Task` blocks. [7b9e10d]
- [x] Task: Conductor - User Manual Verification 'Phase 3: Update UI and AppState for Async I/O' (Protocol in workflow.md)

## Phase 4: Final Verification and Smoke Test [checkpoint: 2452dc2]
- [x] Task: Build the project and perform a manual sanity check. [de8df19]
- [x] Task: Conductor - User Manual Verification 'Phase 4: Final Verification and Smoke Test' (Protocol in workflow.md)
