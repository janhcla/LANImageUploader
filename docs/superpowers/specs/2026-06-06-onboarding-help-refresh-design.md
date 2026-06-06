# Onboarding and Help Refresh

## Goal

Modernize ImageDropX onboarding and help for iOS 26 while accurately covering
photo capture, document scanning, PDF creation, local gallery management,
archives, and SMB upload.

## Product Decisions

- Keep all new copy in English to match the existing app.
- Optimize onboarding for a fast start rather than server configuration.
- Explain that SMB upload is configured in Settings.
- Show a persistent Home setup card until required server settings exist.
- Provide a complete, searchable, offline Help Center.
- Use native iOS 26 Liquid Glass APIs and accessible SwiftUI layouts.

## Onboarding

Use four full-screen chapters:

1. **Welcome and privacy**: Images and documents remain on-device until upload.
2. **Capture and scan**: Explain photo capture, document scanning, edge
   detection, and multi-page capture.
3. **Organize and create PDF**: Explain Gallery actions, archive, and PDF output.
4. **Ready and setup location**: Direct users to
   `Settings > Server Connection` and explain the Home setup card.

The flow supports swipe navigation and explicit Back, Continue, Skip, and Start
actions. Page indicators expose progress. Dynamic Type may scroll vertically.
Reduced Motion removes decorative transitions. Skipping or completing marks
onboarding complete. Help can replay it.

## Home Setup Card

When server IP, share name, username, or password is missing, Home displays a
prominent setup card above the primary actions. The card explains that capture
works immediately but upload needs an SMB connection. Its action navigates to
Settings. It disappears automatically when required settings are complete.

## Help Center

Replace the current text list with a searchable, offline Help Center.

The overview contains:

- Search.
- Quick actions for server setup and replaying onboarding.
- Topic cards for Photos and Scanner, Gallery and PDF, Upload and Server,
  Archive and Files, Privacy and Storage, and Troubleshooting.

Articles use typed Swift data with a title, summary, searchable keywords,
numbered steps, and optional tip or warning. Initial coverage includes:

- Photo capture and retake.
- Document scanning, auto-capture, crop, rotate, and review.
- Gallery selection, rename, reorder, delete, and output choices.
- Single-PDF creation and PDF settings.
- Archive and restore.
- Server discovery and manual configuration.
- Upload, duplicate handling, trial limits, and common failures.
- Privacy, on-device storage, permissions, and network troubleshooting.

## Visual System

- Retain the app's animated blue/purple background with restrained movement.
- Use native `GlassEffectContainer`, `glassEffect`, and glass button styles.
- Use consistent continuous rounded rectangles and SF Symbols.
- Reserve tinted glass for primary actions and status communication.
- Avoid glass on dense article text; use readable grouped content surfaces.
- Support light/dark mode, Dynamic Type, VoiceOver, and Reduce Motion.

## Architecture

- Replace the oversized onboarding file with focused page and component types.
- Keep article content in a dedicated Help content model.
- Keep navigation local to each feature using SwiftUI value-based destinations.
- Continue using the existing `AppData` environment object and
  `onboardingCompleted` AppStorage key.
- Do not change storage, SMB, signing, entitlements, or project configuration.

## Verification

- Build the app on `LANImageUploader iPhone 17 Pro`, iOS 26.5.
- Exercise onboarding completion, skip, and replay.
- Verify the setup card appears with incomplete settings and routes to Settings.
- Verify Help search and article navigation.
- Run an accessibility audit and inspect primary screens at large text sizes.
