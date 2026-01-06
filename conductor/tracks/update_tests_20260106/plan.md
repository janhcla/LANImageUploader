# Plan: Update Tests

## Phase 1: Mock Infrastructure
- [x] Task: Create `LANImageUploaderTests/Mocks/MockFileService.swift`. [1e015e8]
- [x] Task: Create `LANImageUploaderTests/Mocks/MockImageUploadService.swift`. [1e015e8]
- [x] Task: Create `LANImageUploaderTests/Mocks/MockNetworkDiscovery.swift`. [1e015e8]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Mock Infrastructure' (Protocol in workflow.md)

## Phase 2: Refactor AppData Tests
- [ ] Task: Update `LANImageUploaderTests.swift` to initialize `AppData` with mocks.
- [ ] Task: Implement test cases for `saveImagesToDatedFolder` async logic.
- [ ] Task: Implement test cases for upload orchestration and error state handling.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Refactor AppData Tests' (Protocol in workflow.md)

## Phase 3: Final Verification
- [ ] Task: Run all unit tests via `xcodebuild test`.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Final Verification' (Protocol in workflow.md)
