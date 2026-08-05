# Technology Stack - LensBridge (LANImageUploader)

## Core Language & Runtime
- **Swift 6:** The primary programming language for all application logic and UI, utilizing modern concurrency features.

## UI Framework
- **SwiftUI (iOS 26+):** The declarative framework used for building the user interface, incorporating the "Liquid Glass" design system.

## Networking
- **AMSMB2:** Third-party library used for SMB protocol communication to upload files.
- **Bonjour:** Native network service discovery used to find local SMB servers.

## Data & Storage
- **Local File System:** Primary storage for captured images in the app's secure Documents directory.
- **UserDefaults:** Used for storing non-sensitive user preferences and server configuration (excluding passwords).
- **Keychain:** Secure storage for sensitive credentials like SMB passwords.

## Architecture
- **Single Source of Truth:** `AppData` (ObservableObject) injected via `.environmentObject` manages global app state.
- **Service Layer:** Dedicated services (`FileService`, `ImageUploadService`, `NetworkDiscovery`, `HapticFeedbackService`) encapsulate I/O, networking, and tactile feedback logic. `FileService` utilizes a background `FileActor` to ensure non-blocking disk operations.
- **Design System:** A custom "Liquid Glass" component library (including `GlassContainer` and `LiquidButtonStyle`) provides a unified, modern aesthetic with fluid animations.
- **Robust Error Handling:** Brittle string-based error parsing has been replaced with typed `UploadError` and `ConnectionError` enums. Underlying SMB and networking errors are mapped to these types to provide reliable user guidance and logic flow.
- **Dependency Injection:** Services are abstracted via protocols (`FileServiceProtocol`, `HapticFeedbackServiceProtocol`, etc.) and injected into `AppData` via constructor injection to enable unit testing and decoupling.
- **Isolated Unit Testing:** Mock implementations of service protocols allow for fast, reliable, and isolated testing of application logic without requiring disk or network access.
- **Centralized Constants:** A project-wide `Constants` namespace ensures type-safe access to UserDefaults keys, Keychain accounts, Notification names, and background task identifiers.
