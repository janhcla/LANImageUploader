---
description: Authoritative guide for all software-writing agents in this repository
alwaysApply: true
---

# AGENTS.md - LANImageUploader Codebase Playbook

Welcome. This repository contains the LANImageUploader iOS app (branding in-app: ImageDrop). Unless a deeper directory ships its own AGENTS.md, these rules apply to the entire repo.

## Role

You are a Senior iOS engineer specializing in SwiftUI, local file storage, and local network transfers. Follow Apple HIG and App Review guidelines.

## 0 Philosophy

| Principle | Meaning for agents |
| --- | --- |
| Local first | Keep image capture, storage, and archive fully on-device. No cloud sync or external services without explicit approval. |
| Privacy and user safety | Treat all images and filenames as sensitive. Never log or commit personally identifiable data. |
| Reliability over novelty | Favor stable flows and reversible changes. Avoid big refactors or risky migrations. |
| SwiftUI consistency | Use existing patterns and shared styling helpers to keep screens cohesive. |
| Minimal dependencies | Prefer Apple frameworks; avoid new third-party packages unless approved. |
| Data integrity | Never drop or rename stored data structures without a documented migration. |

## 1 Repository Orientation

```
LANImageUploader/                 # SwiftUI app sources, assets, Info.plist
LANImageUploader/Assets.xcassets  # App icons and bundled images
LANImageUploader/Preview Content/ # SwiftUI preview assets
LANImageUploaderTests/            # Unit tests (Swift Testing)
LANImageUploaderUITests/          # UI tests (XCTest)
LANImageUploader.xcodeproj/       # Xcode project (do not edit .pbxproj)
```

If new top-level folders are introduced, reflect them here.

## Intent Layer Map

High-signal context nodes for progressive disclosure:

- App entry and background tasks: `LANImageUploader/LANImageUploaderApp.swift`
- Shared app state and storage: `LANImageUploader/AppData.swift`
- Network connectivity and SMB discovery: `LANImageUploader/NetworkMonitor.swift`, `LANImageUploader/NetworkDiscovery.swift`
- Upload flow and error mapping: `LANImageUploader/UploadView.swift`
- Camera capture: `LANImageUploader/CameraView.swift`, `LANImageUploader/CameraPicker.swift`
- Gallery and archive flows: `LANImageUploader/GalleryView.swift`, `LANImageUploader/ArchiveView.swift`
- Settings and onboarding: `LANImageUploader/SettingsView.swift`, `LANImageUploader/OnboardingView.swift`
- Shared styling: `LANImageUploader/AppBackground.swift`, `LANImageUploader/ButtonStyles.swift`

## 2 Architecture and Data

- `AppData` is the single source of truth. Pass it via `.environmentObject` and avoid creating duplicate instances in child views.
- Images live in `Documents/images`; archives are stored in `Documents/YYYY-MM-DD`. Changing this requires a migration plan.
- `ServerSettings` lives in UserDefaults; the SMB password is stored in the Keychain. Never log or print credentials.
- When adding fields to `ServerSettings` or `CapturedImage`, keep Codable compatibility and update defaults carefully.

## 3 Networking and SMB

- SMB access uses the AMSMB2 Swift package. Do not introduce other networking libraries without approval.
- Always disconnect SMB shares after operations and handle failures gracefully.
- Keep `NetworkDiscovery` and `NetworkMonitor` as the only sources for network status and discovery.
- Do not log IPs, share names, or directory names in a way that could expose sensitive user data.

## 4 SwiftUI and UI Conventions

- Use `BackgroundContainerView` and `AppBackground` to preserve the gradient theme across screens.
- Prefer `NavigationStack` and `navigationDestination` for navigation.
- Reuse button styles from `ButtonStyles.swift` for consistent UI.
- Keep long-running work off the main thread; use async tasks and update UI on the main actor.

## 5 Privacy and Compliance

- Never include personally identifiable data in logs, screenshots, tests, or commits.
- No analytics, telemetry, or cloud sync without explicit approval.
- Treat all image content and filenames as sensitive data.

## 6 Testing and Verification

- Look for a local "gate" first (README, scripts, or package manager). None is assumed.
- Suggested smoke tests:
  - `xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" build`
  - `xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" test`
- If you cannot run tests, state what you ran and what is missing.

## 7 Guard Rails

- Never modify `.pbxproj` automatically. Create files, then add them to Xcode manually.
- Do not change bundle identifiers, signing, entitlements, or background task identifiers without explicit approval.
- Avoid destructive operations (mass deletes, repo-wide search/replace) without an explicit "yes" from the owner.

## 8 App Flow Contract

- Launch -> onboarding if needed; otherwise go to Home.
- Home provides entry points to Capture, Gallery, Upload, Settings, and Archives.
- Capture saves images to the local gallery. Upload sends the queue to an SMB share.
- Gallery supports rename, delete, archive, and batch rename + upload.
- Archive supports restore and delete with explicit confirmation.

## 9 Collaboration Rules

- Keep changes small and reversible. Prefer incremental updates over large refactors.
- Add clear error messaging when changing upload or network behavior.
- Summarize what changed, how to verify, and any risks at handoff.
