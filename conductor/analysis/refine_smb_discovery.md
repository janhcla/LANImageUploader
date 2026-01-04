# Analysis: Refine SMB Discovery and Connection

## Current State Analysis

### NetworkDiscovery.swift
- **Strengths:** Implements robust discovery strategies including fast subnet scanning and Bonjour. Uses `AMSMB2` for the heavy lifting.
- **Weaknesses:**
    - `retrieveNetworkInfo` is a long, monolithic function.
    - Status updates are logged but not broadcast to the UI.
    - Error handling aggregates distinct failures into generic codes, losing nuance.
    - No cancellation support for the discovery process.

### AppData.swift
- **Strengths:** Centralized source of truth.
- **Weaknesses:**
    - Lacks a dedicated `ConnectionState` model.
    - `ServerSettings` updates trigger auto-save but don't inherently trigger connection re-validation or status updates.

## Proposed Architecture for State

We will introduce a `ConnectionStatus` enum to `AppData.swift` (or a new file) to represent:

```swift
enum ConnectionStatus: Equatable {
    case disconnected
    case discovery(DiscoveryState)
    case connecting(String) // IP or Hostname
    case authenticating
    case connected(NetworkInfo)
    case failure(ConnectionError)
}

enum DiscoveryState: Equatable {
    case subnetScan(progress: Double)
    case bonjourSearch
    case resolving(String) // Service Name
}
```

This will allow the UI to show exactly what is happening: "Scanning network (30%)...", "Found Server, Authenticating...", etc.
