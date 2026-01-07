# Implementation Plan: Enhanced OCR Reliability and Speed

This plan outlines the steps to optimize the text recognition feature in the "Name Your Image" sheet, focusing on speed, automatic capture, and clear user feedback.

## Phase 1: Core OCR Optimization & Logic
Focus: Improving text detection reliability and implementing the auto-capture logic.

- [ ] **Task 1: Optimize DataScanner Configuration**
    - [ ] Sub-task: Write unit tests for text validation logic (e.g., filtering out short/invalid strings).
    - [ ] Sub-task: Update `OCRCameraView` to use continuous scanning with high-confidence thresholds.
- [ ] **Task 2: Implement Auto-Capture and Confidence Logic**
    - [ ] Sub-task: Modify the `Coordinator` to automatically select the first valid text item without requiring a user tap.
    - [ ] Sub-task: Implement a debouncing or "stable match" timer to ensure the detected text is clear before capturing.
- [ ] **Task 3: Conductor - User Manual Verification 'Phase 1: OCR Logic' (Protocol in workflow.md)**

## Phase 2: User Experience & Visual Feedback
Focus: Implementing the "freeze" effect and streamlining the transition back to the text field.

- [ ] **Task 1: Implement "Freeze" Verification Effect**
    - [ ] Sub-task: Add a state to pause the `DataScannerViewController` or overlay a static snapshot upon capture.
    - [ ] Sub-task: Implement the 1-second auto-dismissal logic after a successful capture.
- [ ] **Task 2: Refine UI Feedback and Haptics**
    - [ ] Sub-task: Add a visual "highlight" animation to the text field when text is imported.
    - [ ] Sub-task: Synchronize the "liquid" haptic pulse with the exact moment of capture.
- [ ] **Task 3: Conductor - User Manual Verification 'Phase 2: OCR UX' (Protocol in workflow.md)**
