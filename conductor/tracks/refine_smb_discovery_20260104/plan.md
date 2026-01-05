# Plan: Refine SMB Discovery and Connection

## Phase 1: Analysis & State Infrastructure [checkpoint: 68d1ed4]
- [x] Task: Analyze existing `NetworkDiscovery.swift` and `AppData.swift` connection logic. [f1c7eb9]
- [x] Task: Define a comprehensive `ConnectionStatus` enum to represent granular states. [4c0be1a]
- [x] Task: Conductor - User Manual Verification 'Phase 1: Analysis & State Infrastructure' (Protocol in workflow.md)

## Phase 2: Discovery Refinement [checkpoint: 6c8eb7d]
- [x] Task: Implement timeout handling and retry logic for Bonjour discovery in `NetworkDiscovery.swift`. [74e13a1]
- [x] Task: Write unit tests for the discovery manager to verify service detection and removal. [74e13a1]
- [x] Task: Update the UI in `SettingsView` to show a progress indicator during discovery. [66c96ed]
- [x] Task: Fix `NetworkMonitor` initialization race condition to prevent false "No Network" errors. [be7eb48]
- [x] Task: Conductor - User Manual Verification 'Phase 2: Discovery Refinement' (Protocol in workflow.md)

## Phase 3: Interactive Discovery & Validation [checkpoint: 3b96af7]
- [x] Task: Implement detailed `ConnectionError` mapping (auth vs network). [3b96af7]
- [x] Task: Extend `NetworkDiscovery` for "List Hosts" mode. [3b96af7]
- [x] Task: Create `DiscoveryResultsView` UI (list hosts, then shares). [3b96af7]
- [x] Task: Integrate into `SettingsView` and `OnboardingView`. [3b96af7]
- [x] Task: Conductor - User Manual Verification 'Phase 3: Interactive Discovery & Validation' (Protocol in workflow.md)