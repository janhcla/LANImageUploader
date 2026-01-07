# Specification: Enhanced OCR Reliability and Speed

## Overview
This track focuses on improving the performance, reliability, and user experience of the text recognition (OCR) feature within the "Name Your Image" sheet. The goal is to provide a fast, "point-and-scan" experience that accurately captures text from the camera and automatically populates the name field with minimal friction.

## Functional Requirements

### 1. Optimized Inline Viewfinder
- **Real-time Scanning:** Implement a continuous scanning approach that analyzes frames in real-time, prioritizing speed and confidence.
- **Improved DataScanner Integration:** Refine the `DataScannerViewController` configuration to better handle variable lighting and distances.

### 2. Automatic Text Capture & "Freeze" Feedback
- **First-Match Logic:** Automatically capture the first high-confidence text item detected.
- **Verification Freeze:** When text is successfully captured, the viewfinder will briefly "freeze" (pause the camera stream) to allow the user to verify the result before the view closes.
- **Visual Feedback:** Provide a clear visual indicator (e.g., a subtle highlight or scale effect on the text field) when text is automatically imported.

### 3. Haptic & Sound Integration
- **Capture Cue:** Trigger a distinct "liquid" haptic pulse when text is successfully recognized and captured.
- **Transition Feedback:** Ensure smooth haptic-synced transitions when opening and closing the OCR viewfinder.

## Non-Functional Requirements
- **Latency:** Text recognition should occur within <500ms of the text entering the viewfinder's "sweet spot."
- **Accuracy:** Prioritize high-confidence strings to avoid capturing random background noise.
- **Battery/Thermal Efficiency:** Ensure the real-time scanner does not cause excessive thermal throttling during typical use.

## Acceptance Criteria
- [ ] OCR camera opens quickly when tapping the camera icon.
- [ ] Text is recognized and automatically populates the "Enter name..." field without requiring a manual tap on the text itself.
- [ ] The camera view briefly freezes upon capture for user verification.
- [ ] The OCR view dismisses automatically after the brief freeze period.
- [ ] Haptic feedback accurately signals a successful capture.

## Out of Scope
- Full-screen OCR viewfinder (keeping it inline).
- Multi-line text recognition or complex document scanning.
- Cloud-based OCR processing (keeping it local-only).
