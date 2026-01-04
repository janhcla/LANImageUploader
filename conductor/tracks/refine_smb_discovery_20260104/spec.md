# Spec: Refine SMB Discovery and Connection

## Overview
This track aims to improve the reliability and user experience of connecting to SMB shares. Key focus areas include Bonjour discovery success rates, detailed connection feedback, interactive server selection, and robust validation of server settings.

## Objectives
- **Reliable Discovery:** Improve the Bonjour discovery process to more consistently find SMB servers on the local network.
- **Granular Feedback:** Provide real-time status updates during the connection process (e.g., "Scanning...", "Connecting to Host...", "Authenticating...").
- **Interactive Selection:** Instead of auto-connecting to the first found server, present a list of discovered hosts and their shares for user selection.
- **Robust Error Handling:** Distinguish between common failure modes (network unreachable, authentication failed, share not found) and provide actionable feedback (e.g., "Wrong Password" instead of generic error codes).

## User Stories
- As a user, I want to see a list of available SMB servers on my network so I don't have to type IP addresses.
- As a user, I want to browse the shares available on a server and select the one I want to use.
- As a user, I want to know exactly what is happening while the app is connecting to my server.
- As a user, I want helpful advice if my connection attempt fails (e.g. "Check your password").

## Technical Scope
- **NetworkDiscovery.swift:** Enhance service browser logic, timeout handling, and support for "List Hosts" mode.
- **AppData.swift:** Add granular connection states and improve SMB handshake logic.
- **SettingsView.swift:** Update UI to reflect detailed connection status and integrate the new interactive selection flow.
- **DiscoveryResultsView (New):** A new view to display found servers and shares.
- **NetworkMonitor.swift:** Fix initialization race conditions.