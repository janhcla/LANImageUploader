# Plan: Introduce Dependency Injection and Service Protocols

## Phase 1: Define Service Abstractions
- [x] Task: Create protocols for `FileServiceProtocol`, `ImageUploadServiceProtocol`, and `NetworkDiscoveryProtocol`. [e7927ef]
- [x] Task: Update `FileService`, `ImageUploadService`, and `NetworkDiscovery` to conform to these protocols. [70ad9cd]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Define Service Abstractions' (Protocol in workflow.md)

## Phase 2: Refactor AppData for Dependency Injection
- [ ] Task: Update `AppData` properties to store services as protocol types.
- [ ] Task: Refactor `AppData.init` to use constructor injection for all three services.
- [ ] Task: Update all `AppData` logic to use internal service instances instead of static `.shared` access.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Refactor AppData for Dependency Injection' (Protocol in workflow.md)

## Phase 3: Wire Dependencies at App Entry Point
- [ ] Task: Update `LANImageUploaderApp` to instantiate concrete services and inject them into the `AppData` initializer.
- [ ] Task: Identify and refactor any remaining direct `.shared` service calls in Views to use the instances provided by `AppData` (where appropriate).
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Wire Dependencies at App Entry Point' (Protocol in workflow.md)

## Phase 4: Final Integration and Parity Check
- [ ] Task: Verify the build and perform a manual end-to-end smoke test (Capture -> Gallery -> Archive -> Upload).
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Integration and Parity Check' (Protocol in workflow.md)
