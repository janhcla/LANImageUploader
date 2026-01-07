# Spec: Refactor Hardcoded Keys and Strings

## Overview
This track addresses Issue #4 from the initial code assessment: "Refactor Hardcoded Keys/Strings". Currently, the application uses scattered hardcoded strings for UserDefaults keys, Keychain keys, Notification names, and other identifiers. This track aims to centralize these values into a structured `Constants` enum to improve maintainability, reduce the risk of typos, and make the codebase cleaner.

## Objectives
- **Centralization:** Move all "magic strings" used as keys or identifiers into a single `Constants.swift` file.
- **Type Safety:** Use enums and static properties to ensure type safety and leverage compiler checks.
- **Readability:** Improve code readability by using semantic names instead of raw string literals.

## Functional Requirements
- **Create `Constants.swift`:** Define a file to house the centralized constants.
- **Define Enum Structure:**
    - `Constants.Keychain`: For keychain account keys (e.g., "serverPassword").
    - `Constants.UserDefaults`: For UserDefaults keys (e.g., "serverSettings", "onboardingCompleted", "archiveCustomNames").
    - `Constants.Notifications`: For Notification names (e.g., "NetworkMonitorStateChanged", "ArchivedImageDeleted").
    - `Constants.BackgroundTasks`: For BGTaskScheduler identifiers (e.g., "com.janhagenclausen.LANImageUploader.dailyImageSave").
- **Refactor Usage:**
    - Update `AppData.swift` to use `Constants.Keychain` and `Constants.UserDefaults`.
    - Update `LANImageUploaderApp.swift` to use `Constants.UserDefaults` and `Constants.BackgroundTasks`.
    - Update `NetworkMonitor.swift` to use `Constants.Notifications`.
    - Update `ArchiveView.swift` to use `Constants.UserDefaults` and `Constants.Notifications`.
    - Update `SettingsView.swift` to remove any redundant local string definitions (if any).

## Non-Functional Requirements
- **No Logic Changes:** This refactoring must strictly be a replacement of values. No logic or behavior should change.
- **Build Integrity:** The project must compile successfully after all replacements.

## Acceptance Criteria
- No hardcoded string literals used for keys or identifiers remain in the refactored files.
- `Constants` enum is used consistently across the project.
- The app builds and runs without errors.

## Out of Scope
- Localization of user-facing strings (UI text).
- Error message strings (unless used as keys).
