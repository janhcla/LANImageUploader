# Plan: Refine SMB Discovery and Connection

## Phase 1: Analysis & State Infrastructure [checkpoint: 68d1ed4]
- [x] Task: Analyze existing `NetworkDiscovery.swift` and `AppData.swift` connection logic. [f1c7eb9]
- [x] Task: Define a comprehensive `ConnectionStatus` enum to represent granular states. [4c0be1a]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Analysis & State Infrastructure' (Protocol in workflow.md)

## Phase 2: Discovery Refinement
- [x] Task: Implement timeout handling and retry logic for Bonjour discovery in `NetworkDiscovery.swift`. [74e13a1]
- [x] Task: Write unit tests for the discovery manager to verify service detection and removal. [74e13a1]
- [ ] Task: Update the UI in `SettingsView` to show a progress indicator during discovery.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Discovery Refinement' (Protocol in workflow.md)

## Phase 3: Connection Feedback & Validation
- [ ] Task: Enhance the SMB connection handshake in `AppData` to report granular state changes.
- [ ] Task: Implement detailed error mapping from `AMSMB2` errors to user-friendly messages.
- [ ] Task: Write unit tests for server settings validation and error mapping.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Connection Feedback & Validation' (Protocol in workflow.md)
