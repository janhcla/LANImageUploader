# LANImageUploader (ImageDrop)

LANImageUploader is a SwiftUI iOS app for capturing clinical photos, managing a local gallery, and uploading images to an SMB share on the local network. In-app branding appears as "ImageDrop".

## Features

- Capture photos and store them locally on-device.
- Manage a gallery (rename, batch rename, delete).
- Upload queued images to an SMB share on the LAN.
- Archive images by date and restore from archives.
- Optional auto-discovery of SMB servers on the local network.

## Requirements

- Xcode with iOS Simulator support.
- iOS 18+ target (see project settings).
- SMB server reachable on the same network.

## Setup

1. Open `LANImageUploader.xcodeproj` in Xcode.
2. Build/run on a simulator or device.
3. Configure server settings in-app:
   - Server IP
   - Share name
   - Optional target directory
   - Username + password
   - Optional port

The app uses local network access and Bonjour discovery to auto-fill settings when possible.

## Build

List schemes:

```sh
xcodebuild -list -project LANImageUploader.xcodeproj
```

Build on a simulator (adjust device/OS as available):

```sh
xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" build
```

## Privacy

All images and metadata are stored on-device. No analytics or cloud sync are included.

## Contributing

See `AGENTS.md` for coding and repository rules.
