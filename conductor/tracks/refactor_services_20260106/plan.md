# Plan: Refactor Architecture - Extract Logic to Services

## Phase 1: Service Layer Infrastructure [checkpoint: 3d9df12]
- [x] Task: Implement `FileService` to handle all local `FileManager` operations. [70c1f8d]
- [x] Task: Implement `ImageUploadService` to encapsulate SMB networking logic. [450b27d]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Service Layer Infrastructure' (Protocol in workflow.md)

## Phase 2: Refactoring Gallery and Archive Logic [checkpoint: 54417f7]
- [x] Task: Migrate archiving and saving logic from `AppData` to `FileService`. [c48fe23]
- [x] Task: Refactor `GalleryView` to use `FileService` for deletion and renaming. [c48fe23]
- [x] Task: Conductor - User Manual Verification 'Phase 2: Refactoring Gallery and Archive Logic' (Protocol in workflow.md)

## Phase 3: Refactoring Upload Logic [checkpoint: 70ee6ac]
- [x] Task: Relocate SMB connection and upload logic from `UploadView` to `ImageUploadService`. [54b0dd9]
- [x] Task: Update `UploadView` to interact solely with the service and `AppData` status. [54b0dd9]
- [x] Task: Conductor - User Manual Verification 'Phase 3: Refactoring Upload Logic' (Protocol in workflow.md)

## Phase 4: Final Cleanup and Integration
- [ ] Task: Remove redundant I/O methods and imports from `AppData` and Views.
- [ ] Task: Perform a full end-to-end manual test of the Capture -> Gallery -> Archive -> Upload flow.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Cleanup and Integration' (Protocol in workflow.md)
