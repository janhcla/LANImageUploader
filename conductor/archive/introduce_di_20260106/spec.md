# Spec: Introduce Dependency Injection and Service Protocols

## Overview
This track focuses on improving the testability and modularity of the application by introducing Dependency Injection (DI) and protocol-based abstractions for the core services. By decoupling `AppData` from concrete service implementations, we enable the use of mocks in unit tests and follow SOLID principles.

## Objectives
- **Enable Unit Testing:** Abstract side-effect-heavy logic (Disk I/O, Networking) behind protocols so they can be mocked.
- **Implement Constructor Injection:** Refactor `AppData` to receive its dependencies during initialization.
- **Standardize Service Interfaces:** Define clear protocols for File management, Image uploading, and Network discovery.

## Functional Requirements
- **Protocol Definitions:**
    - `FileServiceProtocol`: Methods for archiving, saving, deleting, and listing images.
    - `ImageUploadServiceProtocol`: Methods for SMB uploading and progress tracking.
    - `NetworkDiscoveryProtocol`: Methods for Bonjour and subnet discovery.
- **Service Conformance:**
    - Update `FileService`, `ImageUploadService`, and `NetworkDiscovery` to conform to their respective protocols.
- **AppData Refactoring:**
    - Update `AppData` to store dependencies as protocol types rather than concrete classes.
    - Implement a custom `init` that accepts these protocols.
    - Update all internal calls to use the local dependency instances instead of `.shared` statics.
- **App Entry Point:**
    - Update `LANImageUploaderApp` to instantiate and inject the concrete services into `AppData`.

## Non-Functional Requirements
- **Architecture:** Transition from "Singleton Access" to "Dependency Injection".
- **Maintainability:** Ensure that the new initializer has sensible defaults if possible (though explicit injection at the app level is preferred).

## Acceptance Criteria
- `AppData.swift` no longer contains direct references to `FileService.shared`, `ImageUploadService.shared`, or `NetworkDiscovery.shared`.
- The project builds successfully.
- Functional parity: The app works exactly as before during manual use.

## Out of Scope
- Updating existing unit tests or adding new ones (deferred to a later track).
- Addressing Issue #2 (Blocking I/O), #4 (Constants), or #5 (Typed Errors).
