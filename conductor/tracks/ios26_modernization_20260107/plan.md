# Implementation Plan: iOS 26 "Liquid Glass" Modernization

This plan outlines the steps to modernize LANImageUploader with the iOS 26 "Liquid Glass" design language and enhanced gallery features.

## Phase 1: Foundation & Liquid Glass Design System
Focus: Establishing the core visual building blocks and updating global styles.

- [x] **Task 1: Define Liquid Glass View Modifiers**
    - [x] Sub-task: Write unit tests for visual utility logic (e.g., translucency calculations, if applicable).
    - [x] Sub-task: Implement `LiquidGlassModifier` and `GlassContainer` views.
- [x] **Task 2: Update Global Button and Background Styles**
    - [x] Sub-task: Update `AppBackground.swift` to support the iOS 26 refractive background style.
    - [x] Sub-task: Update `ButtonStyles.swift` with bouncy "liquid" interaction animations.
- [ ] **Task 3: Conductor - User Manual Verification 'Phase 1: Foundation' (Protocol in workflow.md)**

## Phase 2: Modernized Camera Experience
Focus: Updating the capture interface with modern feedback and iOS 26 aesthetics.

- [ ] **Task 1: Refactor Camera Feedback Logic**
    - [ ] Sub-task: Write unit tests for haptic trigger logic and auto-enhancement state management.
    - [ ] Sub-task: Implement `HapticFeedbackService` (or equivalent) for precise iOS 26 haptics.
- [ ] **Task 2: Implement iOS 26 Camera UI Overlay**
    - [ ] Sub-task: Update `CameraView.swift` with the new Liquid Glass overlay and controls.
    - [ ] Sub-task: Integrate fluid animations for focus and exposure feedback.
- [ ] **Task 3: Conductor - User Manual Verification 'Phase 2: Camera' (Protocol in workflow.md)**

## Phase 3: Enhanced Gallery & Batch Management
Focus: Streamlining image management with a robust multi-select experience.

- [ ] **Task 1: Implement Multi-Select and Batch Logic**
    - [ ] Sub-task: Write unit tests for multi-selection, batch renaming, and batch archiving logic.
    - [ ] Sub-task: Implement selection state management in `AppData`.
- [ ] **Task 2: Build the Multi-Select Toolbar**
    - [ ] Sub-task: Create `MultiSelectToolbarView` with modern Liquid Glass styling.
    - [ ] Sub-task: Integrate toolbar into `GalleryView` with appearing/disappearing animations.
- [ ] **Task 3: Modernize Gallery Grid and Sheets**
    - [ ] Sub-task: Update `ImageRowView` and `GalleryView` containers with Liquid Glass aesthetics.
    - [ ] Sub-task: Modernize `NamingSheet` and `ArchiveView` for the new design language.
- [ ] **Task 4: Conductor - User Manual Verification 'Phase 3: Gallery' (Protocol in workflow.md)**

## Phase 4: Animations, Hero Transitions & Polishing
Focus: Adding the "delightful" layers of fluid transitions and micro-interactions.

- [ ] **Task 1: Implement Hero Animations**
    - [ ] Sub-task: Implement smooth transitions from `GalleryView` grid items to `FullscreenImageView`.
    - [ ] Sub-task: Ensure navigation transitions adhere to iOS 26 fluid patterns.
- [ ] **Task 2: Final UI Polishing and Performance Audit**
    - [ ] Sub-task: Conduct a sweep of the app for consistent haptic integration.
    - [ ] Sub-task: Optimize view rendering for 60+ FPS performance during "liquid" animations.
- [ ] **Task 3: Conductor - User Manual Verification 'Phase 4: Final Polishing' (Protocol in workflow.md)**
