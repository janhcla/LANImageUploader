# App Store screenshot drafts

The selected product name is **LensBridge** with the subtitle **Private Photo &
Scan Transfer**. The refreshed English set is already uploaded to App Store
Connect and reports `COMPLETE` for all three assets.

The canonical iPhone set is `asc-6.9/en-US/`: three promotional screenshots
sized 1320×2868 for the 6.9-inch iPhone slot. The canonical iPad set is
`asc-ipad-13/en-US/`. They use simulator captures with synthetic, non-sensitive
empty states only; no patient data, server addresses, usernames, or passwords are
included. Duplicate pre-localization exports remain local-only.

Visual review on 2026-07-25 found that all three current marketing screenshots
are consistent with the LensBridge messaging and contain no patient data,
credentials, or real server values. Screenshot 03 was regenerated from a
current empty Settings capture; the obsolete personal footer is no longer
present. The corrected en-US set
was uploaded to App Store Connect and all three assets report `COMPLETE`.

The required 13-inch iPad set is now also uploaded for `en-US` using display
type `APP_IPAD_PRO_3GEN_129`. The three 2064×2752 PNG assets are in
`asc-ipad-13/en-US/` and the ASC set is
`faceeb45-fca3-4723-8b2c-1b9c77dd44ee`; all three assets report `COMPLETE`.
They are promotional compositions built from current LensBridge UI captures.
They contain no notifications, patient data, credentials, or real server
values. The scanner artwork uses the existing reviewed marketing capture;
the simulator camera itself cannot provide a real document scene.

The Danish version localization currently has no separate screenshot set. Apple
can use the English set as the storefront fallback; add translated variants only
if a Danish-language presentation is required before submission.

The example values visible in Settings (such as `192.168.1.10` and
`MediaCaptureShare`) are UI placeholders from the app, not a real clinic
server or account.

Native simulator source captures remain local-only and are excluded from source
control. Review the final in-app copy and current feature behavior before
uploading anything to App Store Connect. Promotional screenshots are not
evidence that a physical camera or SMB server has been tested.
