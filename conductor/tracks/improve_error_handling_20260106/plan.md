# Plan: Improve Error Handling

## Phase 1: Error Type Enhancement
- [~] Task: Expand `ImageUploadService.UploadError` to include specific cases for conflict, authentication, unreachable, and path errors.
- [x] Task: Add user-facing guidance properties to `UploadError`. [ab44b56]
- [~] Task: Conductor - User Manual Verification 'Phase 1: Error Type Enhancement' (Protocol in workflow.md)

## Phase 2: Refactor Mapping Logic
- [x] Task: Implement a robust `mapUnderlyingError` function in `ImageUploadService` that checks `NSError` domains (`NSPOSIXErrorDomain`, `NSURLErrorDomain`, `AMSMB2ErrorDomain`) and codes. [1e015e8]
- [x] Task: Update `ImageUploadService.upload` to use this mapping for all caught exceptions. [1e015e8]
- [x] Task: Conductor - User Manual Verification 'Phase 2: Refactor Mapping Logic' (Protocol in workflow.md)

## Phase 3: Update UploadView and UI
- [ ] Task: Update `UploadView.detailForUploadError` to switch on `UploadError`.
- [ ] Task: Remove `detailForGenericError` and all string-parsing code.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Update UploadView and UI' (Protocol in workflow.md)

## Phase 4: Final Verification
- [ ] Task: Build the project and perform manual verification of common error states.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Verification' (Protocol in workflow.md)
