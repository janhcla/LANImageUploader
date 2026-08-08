---
description: Authoritative guide for all software-writing agents in this repository
alwaysApply: true
---

# AGENTS.md - LANImageUploader Codebase Playbook

Welcome. This repository contains the LANImageUploader iOS app, branded for release as LensBridge. Unless a deeper directory ships its own AGENTS.md, these rules apply to the entire repo.

## Role

You are a Senior iOS engineer specializing in SwiftUI, local file storage, and local network transfers. Follow Apple HIG and App Review guidelines.

## 0 Philosophy

| Principle | Meaning for agents |
| --- | --- |
| Local first | Keep image capture, storage, and archive fully on-device. No cloud sync or external services without explicit approval. |
| Privacy and user safety | Treat all images and filenames as sensitive. Never log or commit personally identifiable data. |
| Reliability over novelty | Favor stable flows and reversible changes. Avoid big refactors or risky migrations. |
| SwiftUI consistency | Use existing patterns and shared styling helpers to keep screens cohesive. |
| Minimal dependencies | Prefer Apple frameworks; avoid new third-party packages unless approved. |
| Data integrity | Never drop or rename stored data structures without a documented migration. |

## 1 Repository Orientation

```
LANImageUploader/                 # SwiftUI app sources, assets, Info.plist
LANImageUploader/Assets.xcassets  # App icons and bundled images
LANImageUploader/Preview Content/ # SwiftUI preview assets
LANImageUploaderTests/            # Unit tests (Swift Testing)
LANImageUploaderUITests/          # UI tests (XCTest)
LANImageUploader.xcodeproj/       # Xcode project (do not edit .pbxproj)
```

If new top-level folders are introduced, reflect them here.

## Intent Layer Map

High-signal context nodes for progressive disclosure:

- App entry and background tasks: `LANImageUploader/LANImageUploaderApp.swift`
- Shared app state and storage: `LANImageUploader/AppData.swift`
- Network connectivity and SMB discovery: `LANImageUploader/NetworkMonitor.swift`, `LANImageUploader/NetworkDiscovery.swift`
- Upload flow and error mapping: `LANImageUploader/UploadView.swift`
- Camera capture: `LANImageUploader/CameraView.swift`, `LANImageUploader/CameraPicker.swift`
- Gallery and archive flows: `LANImageUploader/GalleryView.swift`, `LANImageUploader/ArchiveView.swift`
- Settings and onboarding: `LANImageUploader/SettingsView.swift`, `LANImageUploader/OnboardingView.swift`
- Shared styling: `LANImageUploader/AppBackground.swift`, `LANImageUploader/ButtonStyles.swift`

## 2 Architecture and Data

- `AppData` is the single source of truth. Pass it via `.environmentObject` and avoid creating duplicate instances in child views.
- Images live in `Documents/images`; archives are stored in `Documents/YYYY-MM-DD`. Changing this requires a migration plan.
- `ServerSettings` lives in UserDefaults; the SMB password is stored in the Keychain. Never log or print credentials.
- When adding fields to `ServerSettings` or `CapturedImage`, keep Codable compatibility and update defaults carefully.

## 3 Networking and SMB

- SMB access uses the AMSMB2 Swift package. Do not introduce other networking libraries without approval.
- Always disconnect SMB shares after operations and handle failures gracefully.
- Keep `NetworkDiscovery` and `NetworkMonitor` as the only sources for network status and discovery.
- Do not log IPs, share names, or directory names in a way that could expose sensitive user data.

## 4 SwiftUI and UI Conventions

- Use `BackgroundContainerView` and `AppBackground` to preserve the gradient theme across screens.
- Prefer `NavigationStack` and `navigationDestination` for navigation.
- Reuse button styles from `ButtonStyles.swift` for consistent UI.
- Keep long-running work off the main thread; use async tasks and update UI on the main actor.

## 5 Privacy and Compliance

- Never include personally identifiable data in logs, screenshots, tests, or commits.
- No analytics, telemetry, or cloud sync without explicit approval.
- Treat all image content and filenames as sensitive data.

## 6 Testing and Verification

- Look for a local "gate" first (README, scripts, or package manager). None is assumed.
- Suggested smoke tests:
  - `xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" build`
  - `xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" test`
- If you cannot run tests, state what you ran and what is missing.

## 7 Guard Rails

- Never modify `.pbxproj` automatically. Create files, then add them to Xcode manually.
- Do not change bundle identifiers, signing, entitlements, or background task identifiers without explicit approval.
- Avoid destructive operations (mass deletes, repo-wide search/replace) without an explicit "yes" from the owner.

## 8 App Flow Contract

- Launch -> onboarding if needed; otherwise go to Home.
- Home provides entry points to Capture, Gallery, Upload, Settings, and Archives.
- Capture saves images to the local gallery. Upload sends the queue to an SMB share.
- Gallery supports rename, delete, archive, and batch rename + upload.
- Archive supports restore and delete with explicit confirmation.

## 9 Collaboration Rules

- Keep changes small and reversible. Prefer incremental updates over large refactors.
- Add clear error messaging when changing upload or network behavior.
- Summarize what changed, how to verify, and any risks at handoff.

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: Bash("openskills read <skill-name>")
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>algorithmic-art</name>
<description>Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. Create original algorithmic art rather than copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>brand-guidelines</name>
<description>Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand colors or style guidelines, visual formatting, or company design standards apply.</description>
<location>project</location>
</skill>

<skill>
<name>canvas-design</name>
<description>Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user asks to create a poster, piece of art, design, or other static piece. Create original visual designs, never copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>doc-coauthoring</name>
<description>Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.</description>
<location>project</location>
</skill>

<skill>
<name>docx</name>
<description>"Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. When Claude needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks"</description>
<location>project</location>
</skill>

<skill>
<name>frontend-design</name>
<description>Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.</description>
<location>project</location>
</skill>

<skill>
<name>internal-comms</name>
<description>A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever asked to write some sort of internal communications (status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, project updates, etc.).</description>
<location>project</location>
</skill>

<skill>
<name>mcp-builder</name>
<description>Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).</description>
<location>project</location>
</skill>

<skill>
<name>pdf</name>
<description>Comprehensive PDF manipulation toolkit for extracting text and tables, creating new PDFs, merging/splitting documents, and handling forms. When Claude needs to fill in a PDF form or programmatically process, generate, or analyze PDF documents at scale.</description>
<location>project</location>
</skill>

<skill>
<name>pptx</name>
<description>"Presentation creation, editing, and analysis. When Claude needs to work with presentations (.pptx files) for: (1) Creating new presentations, (2) Modifying or editing content, (3) Working with layouts, (4) Adding comments or speaker notes, or any other presentation tasks"</description>
<location>project</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.</description>
<location>project</location>
</skill>

<skill>
<name>slack-gif-creator</name>
<description>Knowledge and utilities for creating animated GIFs optimized for Slack. Provides constraints, validation tools, and animation concepts. Use when users request animated GIFs for Slack like "make me a GIF of X doing Y for Slack."</description>
<location>project</location>
</skill>

<skill>
<name>template</name>
<description>Replace with description of the skill and when Claude should use it.</description>
<location>project</location>
</skill>

<skill>
<name>theme-factory</name>
<description>Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. There are 10 pre-set themes with colors/fonts that you can apply to any artifact that has been creating, or can generate a new theme on-the-fly.</description>
<location>project</location>
</skill>

<skill>
<name>web-artifacts-builder</name>
<description>Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.</description>
<location>project</location>
</skill>

<skill>
<name>webapp-testing</name>
<description>Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.</description>
<location>project</location>
</skill>

<skill>
<name>xlsx</name>
<description>"Comprehensive spreadsheet creation, editing, and analysis with support for formulas, formatting, data analysis, and visualization. When Claude needs to work with spreadsheets (.xlsx, .xlsm, .csv, .tsv, etc) for: (1) Creating new spreadsheets with formulas and formatting, (2) Reading or analyzing data, (3) Modify existing spreadsheets while preserving formulas, (4) Data analysis and visualization in spreadsheets, or (5) Recalculating formulas"</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->
