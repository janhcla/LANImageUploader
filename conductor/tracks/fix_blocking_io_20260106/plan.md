# Plan: Fix Blocking I/O

## Phase 1: Background Actor Implementation [checkpoint: 3df87c3]
- [x] Task: Create `LANImageUploader/Services/FileActor.swift` to handle low-level I/O on a background thread. [ab44b56]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Background Actor Implementation' (Protocol in workflow.md)

## Phase 2: Refactor FileService for Asynchronous Operations
- [ ] Task: Update `FileServiceProtocol` to make heavy I/O methods `async`.
- [ ] Task: Update `FileService` implementation to use `FileActor` for archiving, saving, and deleting.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Refactor FileService for Asynchronous Operations' (Protocol in workflow.md)

## Phase 3: Update UI and AppState for Async I/O
- [ ] Task: Refactor `AppData.saveImagesToDatedFolder` to use `await`.
- [ ] Task: Update `GalleryView` and `ArchiveView` to wrap file operations in asynchronous `Task` blocks.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Update UI and AppState for Async I/O' (Protocol in workflow.md)

## Phase 4: Final Verification and Smoke Test
- [ ] Task: Build the project and perform a manual sanity check.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Verification and Smoke Test' (Protocol in workflow.md)
