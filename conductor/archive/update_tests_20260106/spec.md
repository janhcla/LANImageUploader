# Spec: Update Tests

## Overview
This track addresses Issue #7: "Update Tests". With the introduction of service protocols and dependency injection, the existing unit tests in `LANImageUploaderTests` can now be refactored to test the application logic (primarily in `AppData`) in isolation from the actual file system and network. This ensures tests are fast, reliable, and deterministic.

## Objectives
- **Implement Service Mocks:** Create mock implementations for `FileServiceProtocol`, `ImageUploadServiceProtocol`, and `NetworkDiscoveryProtocol`.
- **Decouple AppData Tests:** Refactor `AppData` tests to use injected mocks instead of live services.
- **Increase Coverage:** Add tests for the new asynchronous flows and error handling logic introduced in previous tracks.

## Functional Requirements
- **Mock Services:**
    - `MockFileService`: Allows simulating file presence, directory contents, and I/O errors.
    - `MockImageUploadService`: Allows simulating successful uploads, progress updates, and specific `UploadError` cases.
    - `MockNetworkDiscovery`: Allows simulating Bonjour discovery and server reaching states.
- **AppData Tests:**
    - Verify `saveImagesToDatedFolder` correctly interacts with the file service.
    - Verify `getArchivedDates` correctly parses strings returned by the service.
    - Verify upload orchestration logic handles successes and failures as expected.

## Non-Functional Requirements
- **Speed:** Unit tests should run in milliseconds.
- **Reliability:** Tests should not depend on the environment (WiFi, disk state, SMB servers).

## Acceptance Criteria
- `LANImageUploaderTests` compiles and runs successfully using mocks.
- `AppData` logic is tested without hitting the actual disk or network.
- Project-wide tests pass with `xcodebuild test`.

## Out of Scope
- UI Testing (handled separately in `LANImageUploaderUITests`).
- Integration tests against a real SMB share (requires a specific test environment).
