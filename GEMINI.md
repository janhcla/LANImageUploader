# LANImageUploader (LensBridge)

## Project Overview

LANImageUploader (branded for release as "LensBridge") is a privacy-focused SwiftUI iOS application designed for professional environments. Its primary function is to capture photos and scan documents, manage them locally, and securely upload them to an SMB share on a local network (LAN). It operates on a "local-first" philosophy, ensuring no data is synced to the cloud without explicit configuration.

## Key Features

*   **Image Capture:** Built-in camera integration to capture and store photos locally.
*   **Gallery Management:** View, rename, batch rename, and delete images stored on the device.
*   **LAN Upload:** Upload queued images to a configured SMB share using the `AMSMB2` library.
*   **Network Discovery:** Auto-discovery of SMB servers on the local network via Bonjour.
*   **Archiving:** Automatic and manual archiving of images by date.

## Technical Architecture

*   **Language:** Swift
*   **UI Framework:** SwiftUI
*   **Platform:** iOS 18+
*   **Dependencies:** `AMSMB2` (for SMB networking), otherwise standard Apple frameworks.
*   **State Management:** `AppData` is the single source of truth, injected via `.environmentObject`.
*   **Storage:** Images are stored in the app's `Documents` directory. `UserDefaults` handles simple settings (server config), while Keychain (via `AppData`) manages sensitive credentials.

## Key Files & Directories

*   **`LANImageUploader/`**: Main source code directory.
    *   `LANImageUploaderApp.swift`: App entry point, background task registration, and root view setup.
    *   `AppData.swift`: Central data model and logic for image management and state.
    *   `NetworkMonitor.swift` / `NetworkDiscovery.swift`: Networking logic and SMB discovery.
    *   `UploadView.swift`: UI and logic for uploading images.
    *   `GalleryView.swift`: Image management UI.
    *   `CameraView.swift` / `CameraPicker.swift`: Camera integration.
*   **`AGENTS.md`**: **CRITICAL**. Contains specific rules for AI agents regarding architecture, privacy, and coding standards. Read this before making changes.
*   **`.cursorrules`**: Additional coding rules and context.

## Build & Run

**Requirements:** Xcode with iOS 18+ SDK.

**List Schemes:**
```sh
xcodebuild -list -project LANImageUploader.xcodeproj
```

**Build for Simulator:**
```sh
xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" build
```
*(Note: Adjust `name` and `OS` based on available simulators)*

## Development Conventions

*   **Privacy First:** Treat all data as sensitive data. No cloud sync. No logging of PII/PHI.
*   **UI Consistency:** Use `AppBackground` and `ButtonStyles.swift` to maintain the LensBridge look and feel.
*   **Networking:** Use `AMSMB2` for SMB. Always disconnect shares after use.
*   **Architecture:** Follow the patterns outlined in `AGENTS.md`. `AppData` is the core state container.
*   **Testing:** Run tests via Xcode or `xcodebuild test`.

## Usage

1.  Open `LANImageUploader.xcodeproj`.
2.  Configure a local SMB share for testing (or use the mock/simulator environment if available).
3.  Run the app on a physical device or simulator.
4.  Complete onboarding to reach the Home screen.
