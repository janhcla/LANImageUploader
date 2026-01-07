# Implementation Plan: iOS 26 "Liquid Glass" Modernization

This plan outlines the steps to modernize LANImageUploader with the iOS 26 "Liquid Glass" design language and enhanced gallery features.

## Phase 1: Foundation & Liquid Glass Design System [checkpoint: 03342ac]
Focus: Establishing the core visual building blocks and updating global styles.

- [x] **Task 1: Define Liquid Glass View Modifiers**
    - [x] Sub-task: Write unit tests for visual utility logic (e.g., translucency calculations, if applicable).
    - [x] Sub-task: Implement `LiquidGlassModifier` and `GlassContainer` views.
- [x] **Task 2: Update Global Button and Background Styles**
    - [x] Sub-task: Update `AppBackground.swift` to support the iOS 26 refractive background style.
    - [x] Sub-task: Update `ButtonStyles.swift` with bouncy "liquid" interaction animations.
- [x] **Task 3: Conductor - User Manual Verification 'Phase 1: Foundation' (Protocol in workflow.md)**

## Phase 2: Modernized Camera Experience [checkpoint: 8800f55]
Focus: Updating the capture interface with modern feedback and iOS 26 aesthetics.

- [x] **Task 1: Refactor Camera Feedback Logic**
    - [x] Sub-task: Write unit tests for haptic trigger logic and auto-enhancement state management.
    - [x] Sub-task: Implement `HapticFeedbackService` (or equivalent) for precise iOS 26 haptics.
- [x] **Task 2: Implement iOS 26 Camera UI Overlay**
    - [x] Sub-task: Update `CameraView.swift` with the new Liquid Glass overlay and controls.
    - [x] Sub-task: Integrate fluid animations for focus and exposure feedback.
- [x] **Task 3: Conductor - User Manual Verification 'Phase 2: Camera' (Protocol in workflow.md)**

## Phase 3: Enhanced Gallery & Batch Management [checkpoint: fdc1acc]
Focus: Streamlining image management with a robust multi-select experience.

- [x] **Task 1: Implement Multi-Select and Batch Logic**
    - [x] Sub-task: Write unit tests for multi-selection, batch renaming, and batch archiving logic.
    - [x] Sub-task: Implement selection state management in `AppData`.
- [x] **Task 2: Build the Multi-Select Toolbar**
    - [x] Sub-task: Create `MultiSelectToolbarView` with modern Liquid Glass styling.
    - [x] Sub-task: Integrate toolbar into `GalleryView` with appearing/disappearing animations.
- [x] **Task 3: Modernize Gallery Grid and Sheets**
    - [x] Sub-task: Update `ImageRowView` and `GalleryView` containers with Liquid Glass aesthetics.
    - [x] Sub-task: Modernize `NamingSheet` and `ArchiveView` for the new design language.
- [x] **Task 4: Conductor - User Manual Verification 'Phase 3: Gallery' (Protocol in workflow.md)**

## Phase 4: Animations, Hero Transitions & Polishing [checkpoint: 9ffd9af]
Focus: Adding the "delightful" layers of fluid transitions and micro-interactions.

- [x] **Task 1: Implement Hero Animations**
    - [x] Sub-task: Implement smooth transitions from `GalleryView` grid items to `FullscreenImageView`.
    - [x] Sub-task: Ensure navigation transitions adhere to iOS 26 fluid patterns.
- [x] **Task 2: Final UI Polishing and Performance Audit**
    - [x] Sub-task: Conduct a sweep of the app for consistent haptic integration.
    - [x] Sub-task: Optimize view rendering for 60+ FPS performance during "liquid" animations.
- [x] **Task 3: Conductor - User Manual Verification 'Phase 4: Final Polishing' (Protocol in workflow.md)**
