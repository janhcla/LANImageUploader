# Plan: Introduce Dependency Injection and Service Protocols

## Phase 1: Define Service Abstractions [checkpoint: 2bf8d5f]
- [x] Task: Create protocols for `FileServiceProtocol`, `ImageUploadServiceProtocol`, and `NetworkDiscoveryProtocol`. [e7927ef]
- [x] Task: Update `FileService`, `ImageUploadService`, and `NetworkDiscovery` to conform to these protocols. [70ad9cd]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Define Service Abstractions' (Protocol in workflow.md)

## Phase 2: Refactor AppData for Dependency Injection
- [x] Task: Update `AppData` properties to store services as protocol types. [af48c00]
- [x] Task: Refactor `AppData.init` to use constructor injection for all three services. [af48c00]
- [x] Task: Update all `AppData` logic to use internal service instances instead of static `.shared` access. [af48c00]
- [~] Task: Conductor - User Manual Verification 'Phase 2: Refactor AppData for Dependency Injection' (Protocol in workflow.md)

## Phase 3: Wire Dependencies at App Entry Point
- [x] Task: Update `LANImageUploaderApp` to instantiate concrete services and inject them into the `AppData` initializer. [0103bcf]
- [x] Task: Identify and refactor any remaining direct `.shared` service calls in Views to use the instances provided by `AppData` (where appropriate). [0103bcf]
- [~] Task: Conductor - User Manual Verification 'Phase 3: Wire Dependencies at App Entry Point' (Protocol in workflow.md)

## Phase 4: Final Integration and Parity Check [checkpoint: dc92308]
- [~] Task: Verify the build and perform a manual end-to-end smoke test (Capture -> Gallery -> Archive -> Upload).
- [x] Task: Conductor - User Manual Verification 'Phase 4: Final Integration and Parity Check' (Protocol in workflow.md)
