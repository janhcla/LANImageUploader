# Privacy policy

Last updated: 2026-07-25

This privacy policy describes the current local-first behavior of the iOS app
published in App Store Connect as `LensBridge`.

## Data handled by the app

The app can handle photos, scanned documents, PDFs, filenames, image metadata,
server connection settings, and an SMB password. These files may contain health
or other sensitive information entered or captured by the user.

The app does not collect analytics, advertising identifiers, telemetry, contact
lists, location history, or cloud account data.

## Where data is stored

Captured files, generated PDFs, metadata, and archives remain in the app's local
storage on the device until the user deletes them or chooses to upload a file.
The SMB password is stored in the iOS Keychain. Other connection settings are
stored locally by the app.

When the user uploads a file, the app sends it to the SMB server, share, and target
directory selected by the user. The app does not control what the SMB server or a
separate journal system does with that file afterward.

## Permissions

Camera access is used for photo capture and document scanning. Local Network
access is used to discover and connect to SMB servers. These permissions can be
revoked in iOS Settings; revoking them disables the related feature.

## Retention and deletion

The user controls local retention through Gallery, Archives, and delete actions.
Deleting local files from the app removes them from the app's local storage, but
cannot remove copies already uploaded to an SMB server or imported by another
system. To remove remote copies, follow the clinic or server administrator's
approved procedure.

## Third parties

The app has no cloud backend and does not send files to an analytics or advertising
provider. The user's configured SMB server and any journal system that imports
files are separate systems controlled by the user or their organization.

## Medical and professional scope

The app is a capture, local organization, PDF-generation, and file-transfer tool.
It does not identify patients, diagnose or treat conditions, provide clinical
advice, or replace a patient journal. Users and organizations remain responsible
for lawful handling of sensitive data, access control, backups, retention, and
their journal system's import rules.

## Contact

For privacy questions, use the project's public support channel:
<https://github.com/janhcla/LANImageUploader/issues>.
