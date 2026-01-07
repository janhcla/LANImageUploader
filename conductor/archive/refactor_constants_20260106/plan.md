# Plan: Refactor Hardcoded Keys and Strings

## Phase 1: Define Constants Structure
- [x] Task: Create `LANImageUploader/Constants.swift` and define the `Constants` enum with nested structures for `Keychain`, `UserDefaults`, `Notifications`, and `BackgroundTasks`. [336844d]
- [~] Task: Conductor - User Manual Verification 'Phase 1: Define Constants Structure' (Protocol in workflow.md)

## Phase 2: Refactor Codebase to Use Constants
- [x] Task: Update `AppData.swift` to use `Constants.Keychain` and `Constants.UserDefaults`. [40261c7]
- [x] Task: Update `LANImageUploaderApp.swift` to use `Constants.UserDefaults` and `Constants.BackgroundTasks`. [40261c7]
- [x] Task: Update `NetworkMonitor.swift` to use `Constants.Notifications`. [40261c7]
- [x] Task: Update `ArchiveView.swift` to use `Constants.UserDefaults` and `Constants.Notifications`. [40261c7]
- [~] Task: Conductor - User Manual Verification 'Phase 2: Refactor Codebase to Use Constants' (Protocol in workflow.md)

## Phase 3: Final Verification [checkpoint: 1749f43]
- [x] Task: Perform a final build and quick sanity check to ensure no regressions. [40261c7]
- [x] Task: Conductor - User Manual Verification 'Phase 3: Final Verification' (Protocol in workflow.md)
