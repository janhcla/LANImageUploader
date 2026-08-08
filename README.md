# LANImageUploader (in-app name: LensBridge)

LANImageUploader is a local-first SwiftUI iOS app for capturing clinical photos,
scanning paper documents into multi-page PDFs, managing a local gallery, and
uploading prepared files to an SMB share on the local network. The public product
name is `LensBridge`; the bundle identifier remains unchanged.

## Features

- Capture photos and store them locally on-device.
- Scan multi-page documents with edge detection and optional auto-capture.
- Crop, rotate, reorder, and combine selected pages into a PDF.
- Manage a gallery (rename, batch rename, delete, archive, restore).
- Upload images or PDFs to an SMB share on the LAN.
- Archive images by date and restore from archives.
- Optional auto-discovery of SMB servers on the local network.

## Requirements

- iOS 26 or later (see project settings).
- An iPhone with camera permission for capture and scanning.
- An SMB server reachable on the same local network for uploads.
- An existing journal/EHR system that watches a Windows folder and imports files
  according to its own filename and file-type rules.

## Setup

1. Open `LANImageUploader.xcodeproj` in Xcode.
2. Build/run on a simulator or device.
3. Configure server settings in-app:
   - Server IP or host name
   - Share name
   - Optional target directory
   - Username and password
   - Optional port
4. Test the workflow with a non-sensitive sample file before using clinical data.

The app uses local network access and Bonjour discovery to auto-fill settings when possible.
The in-app Help Center contains the complete step-by-step setup guide and a
troubleshooting checklist for camera permissions, network access, SMB settings,
and journal-folder import verification.

## Build

List schemes:

```sh
xcodebuild -list -project LANImageUploader.xcodeproj
```

Build on a simulator (adjust device/OS as available):

```sh
xcodebuild -scheme LANImageUploader -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" build
```

## Privacy and scope

Images, PDFs, metadata, and archives are stored on-device until the user chooses
to upload a file. The SMB password is stored in the iOS Keychain; other server
settings are stored locally. Uploads go only to the SMB destination configured by
the user. The app contains no analytics, telemetry, or cloud synchronization.

The app does not provide a patient database, patient lookup, diagnosis, clinical
decision support, EHR integration, cloud backup, or remote access. A successful
SMB upload does not prove that a separate journal system imported the file. See
the [privacy policy](PRIVACY.md), [third-party notices](THIRD-PARTY-NOTICES.md),
and the in-app Help Center for the full scope.

## Release documentation

- [Release preflight script](scripts/release_preflight.sh)
- [App Store release plan](docs/APP-STORE-RELEASE-PLAN.md)
- [App Store copy draft](docs/app-store-copy-draft.md)
- [Physical scanner test matrix](docs/SCANNER-PHYSICAL-TEST-MATRIX.md)
- [Candidate product names](docs/product-name-candidates.md)

## Contributing

See `AGENTS.md` for coding and repository rules.
