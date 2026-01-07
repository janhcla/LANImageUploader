# Specification: iOS 26 "Liquid Glass" Modernization

## Overview
This track focuses on upgrading the LANImageUploader (ImageDrop) application to the iOS 26 design language, specifically implementing the "Liquid Glass" aesthetic. The goal is to provide a state-of-the-art, professional, and delightfully modern user experience through refined visuals, expressive micro-interactions, and a streamlined workflow for image capture and gallery management.

## Functional Requirements

### 1. iOS 26 Visual Overhaul
- **Liquid Glass Aesthetic:** Implement the "Liquid Glass" design language globally. This includes translucent, depth-oriented containers, soft refraction effects, and organic, "liquid" edge treatments where Apple intends for this style in iOS 26.
- **Micro-Interactions:** Integrate expressive, bouncy "liquid" animations for buttons and state changes. Ensure all interactions are synced with subtle haptic feedback.
- **Fluid Transitions:** Implement high-quality screen transitions and hero animations (e.g., seamless expansion from gallery grid to fullscreen view).

### 2. Modernized Custom Camera
- **Streamlined Workflow:** Refine the "point-and-shoot" professional experience.
- **Enhanced UI:** Update the camera overlay with iOS 26 styling, ensuring controls are accessible and unobtrusive.
- **Auto-Enhancement:** Implement improved visual feedback during auto-focus and auto-exposure.
- **Haptic Integration:** Add precise haptic cues for shutter fire, mode switching, and focus lock.

### 3. Streamlined Gallery Experience
- **Multi-Select Toolbar:** Implement a robust, modern toolbar for batch actions (renaming, deleting, archiving).
- **Selection Logic:** Improve the ease of selecting multiple images (e.g., drag-to-select support).
- **Renaming/Archiving:** Modernize the sheets and dialogs for renaming and archiving, adhering to the Liquid Glass style.
- **Grid Performance:** Ensure the image grid remains fast and fluid even with large libraries.

## Non-Functional Requirements
- **Performance:** Animations must be buttery smooth (60+ FPS).
- **Usability:** The UI must remain professional and efficient for field use.
- **iOS 18+ Compatibility:** While targeting iOS 26 features, maintain a fallback or graceful degradation for older versions if necessary, though the primary target is the latest platform.
- **Privacy:** Ensure no data leaks or unintended cloud syncing occurs during the UI overhaul.

## Acceptance Criteria
- [ ] Global application of "Liquid Glass" styling to all major containers and interactive elements.
- [ ] Camera captures photos efficiently with modern haptic and visual feedback.
- [ ] Gallery supports batch selection, renaming, and archiving via a cohesive multi-select toolbar.
- [ ] All animations are fluid and respond naturally to user input.
- [ ] All unit and integration tests for new functionality pass.

## Out of Scope
- Implementation of advanced manual camera controls (ISO, Shutter Speed, etc.).
- Cloud-based image processing or storage.
- Significant changes to the underlying SMB/AMSMB2 networking logic.
