# Product Guide - LANImageUploader (ImageDrop)

## Initial Concept
LANImageUploader is a privacy-focused SwiftUI iOS app for capturing professional photos, managing a local gallery, and uploading images to an SMB share on the local network.

## Target Users
- Professionals in environments requiring secure, local-only image transfers (e.g., medical, industrial, field inspections) who need to ensure data never leaves the local network.

## Core Goals
- **Privacy & Security:** Maximum privacy by keeping all data off the cloud and strictly within the local network.
- **Workflow Efficiency:** Providing a seamless and efficient workflow for capturing, managing, and uploading professional photos to network storage.

## Key Features
- **Professional Image Capture:** High-quality camera integration with immediate local storage in the app's secure container.
- **Local Gallery Management:** Comprehensive on-device management including renaming, batch renaming, and deletion of captured images.
- **SMB Upload Engine:** Reliable transfer of queued images to configured SMB shares, supporting professional-grade networking requirements.
- **Network Discovery:** Interactive discovery of SMB servers and shares via Bonjour and subnet scanning, providing real-time status and robust error guidance.
