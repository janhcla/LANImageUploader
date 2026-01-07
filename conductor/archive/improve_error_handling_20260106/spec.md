# Spec: Improve Error Handling

## Overview
This track addresses Issue #5 from the initial code assessment: "Improve Error Handling". Currently, the `UploadView` and other parts of the app rely on parsing localized error description strings (e.g., `lowerDescription.contains("logon failure")`) to determine the cause of failure and provide user guidance. This is brittle because these strings can change with OS versions, locales, or library updates. This track aims to replace this with robust, typed error handling using `ConnectionError` and `UploadError`.

## Objectives
- **Remove Brittle String Parsing:** Eliminate reliance on `.localizedDescription` for logic flow or user guidance mapping.
- **Unified Error Types:** Use the existing `ConnectionError` and enhance `ImageUploadService.UploadError` to cover all SMB and network failure modes.
- **Accurate User Guidance:** Map underlying `AMSMB2`, `NSPOSIXErrorDomain`, and `NSURLErrorDomain` errors directly to typed app errors.

## Functional Requirements
- **Enhance `ConnectionError` and `UploadError`:**
    - Ensure `UploadError` covers duplicates ("already exists"), authentication, host unreachable, and share/folder not found.
- **Refactor `ImageUploadService`:**
    - Update the `upload` method to catch underlying errors and throw specific `UploadError` cases instead of generic ones.
    - Implement a mapping function that inspects `NSError` domains and codes (e.g., `NSPOSIXErrorDomain` code `13` for access denied).
- **Refactor `UploadView`:**
    - Update `detailForUploadError` to switch over the typed `UploadError` enum.
    - Remove `detailForGenericError` and all string-based `contains()` checks.
- **Refactor `NetworkDiscovery`:**
    - Ensure it consistently throws `ConnectionError` by mapping underlying networking errors accurately.

## Non-Functional Requirements
- **Robustness:** Error handling should be independent of system language settings.
- **Clarity:** User-facing guidance should remain high-quality and specific.

## Acceptance Criteria
- `UploadView.swift` contains zero string-based error description parsing.
- All errors from `ImageUploadService` are handled via `switch` statements or typed patterns.
- The app provides correct guidance for:
    - Wrong password (Authentication failure)
    - Server down (Timeout/Host unreachable)
    - File already exists (Conflict)
    - Share not found (Path/Share error)
- The project builds and passes manual verification.

## Out of Scope
- Adding automated unit tests for all error cases (though refactoring makes this easier later).
