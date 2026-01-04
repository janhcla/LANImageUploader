# Technology Stack - LANImageUploader (ImageDrop)

## Core Language & Runtime
- **Swift:** The primary programming language for all application logic and UI.

## UI Framework
- **SwiftUI (iOS 18+):** The declarative framework used for building the user interface.

## Networking
- **AMSMB2:** Third-party library used for SMB protocol communication to upload files.
- **Bonjour:** Native network service discovery used to find local SMB servers.

## Data & Storage
- **Local File System:** Primary storage for captured images in the app's secure Documents directory.
- **UserDefaults:** Used for storing non-sensitive user preferences and server configuration (excluding passwords).
- **Keychain:** Secure storage for sensitive credentials like SMB passwords.

## Architecture
- **Single Source of Truth:** `AppData` (ObservableObject) injected via `.environmentObject` manages global app state.
