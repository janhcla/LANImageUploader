# LANImageUploader (ImageDrop) Code Review Rubric

This document serves as the authoritative code review rubric for all automated and manual code reviews. When reviewing Pull Requests, evaluate changes against these guidelines.

---

## 1. Core Architecture & Local-First Philosophy
*   **Local-First Storage:** All images and archives must remain fully on-device. No cloud storage sync or external communication is permitted without explicit, documented architectural approval.
*   **State Management:** `AppData` is the single source of truth for the entire application. It must be passed via `.environmentObject` in the view hierarchy. Never instantiate multiple copies or bypass this container.
*   **Directory Structure:**
    *   Active/captured images must be stored under `Documents/images/`.
    *   Archived images must be grouped by date under `Documents/YYYY-MM-DD/`.
    *   Any changes to this structure require a documented, safe migration plan.

---

## 2. Security & Data Privacy
*   **Credential Handling:** 
    *   All sensitive credentials (e.g., SMB passwords, tokens) **must** be stored securely in the iOS Keychain.
    *   Only non-sensitive configurations (e.g., server IP, share names, username) may be stored in `UserDefaults`.
*   **Logging Constraints:**
    *   Never log or print passwords, auth tokens, or keys.
    *   Do not log personally identifiable information (PII), local IP addresses, share names, or specific directory paths in production logs.
*   **Networking Sandbox:** All network transfers must be performed over local networks (LAN) using `AMSMB2`. Maintain minimal network privileges.

---

## 3. Local Networking & SMB Connections
*   **SMB Protocol Integration:** Use the standard `AMSMB2` package for all SMB shares. Do not introduce other network file transfer libraries.
*   **Resource Lifecycle:** Always disconnect from the SMB share immediately after completing transfer or discovery tasks. Connection handles must not be kept open indefinitely.
*   **Discovery:** Rely exclusively on `NetworkDiscovery` and `NetworkMonitor` for scanning/tracking network state and auto-discovering local SMB shares via Bonjour.

---

## 4. SwiftUI & User Interface (Apple HIG)
*   **Theme Consistency:** Cohesive dark/gradient styling is a core product requirement. Wrap screen components inside `BackgroundContainerView` or utilize `AppBackground` to preserve the visual theme.
*   **Button Design:** Interactive buttons must leverage the styles defined in `ButtonStyles.swift`. Do not define ad-hoc button styles.
*   **Navigation:** Prefer standard `NavigationStack` with `navigationDestination(for:)` for transitions.
*   **Thread Safety:** Long-running/intensive I/O operations (file writing, network calls) must run asynchronously off the main thread. Ensure all UI updates are dispatched on the `@MainActor`.

---

## 5. Dependency & Project Management
*   **Minimal Dependencies:** Do not introduce third-party Swift packages or CocoaPods unless explicitly approved. Maximize standard Apple framework APIs (SwiftUI, Network, Security, etc.).
*   **Project File Integrity (`.pbxproj`):**
    *   Do not let automated scripts modify `.xcodeproj/project.pbxproj`.
    *   Ensure any new files created are added to Xcode target groups manually or via verified tooling.
*   **App Configuration:** Do not alter the Bundle Identifier, entitlements, background task configurations, or code signing profiles.
