# Premium Feature

## App Store Connect

- App Store Connect app ID: `6742799620`
- Bundle ID: `com.janhagenclausen.LANImageUploader`
- In-app purchase ID: `6769515889`
- Product ID: `com.janhagenclausen.LANImageUploader.fullunlock`
- Type: non-consumable
- Display name: `Full App Unlock`
- Price: `USD 1.99`
- Review screenshot ID: `c365aac8-058d-469e-af1d-d723cf4b099c`
- IAP availability: configured for all 175 available territories, with automatic availability in new territories enabled
- App availability: the app is free and enabled in all available territories.
- Current submitted app version: `1.58 (65)`.
- Current ASC state: the app and `Full App Unlock` are `WAITING_FOR_REVIEW` in
  the same combined submission.

Created and verified with:

```bash
asc iap setup --app 6742799620 --type NON_CONSUMABLE --reference-name "Full App Unlock" --product-id "com.janhagenclausen.LANImageUploader.fullunlock" --locale en-US --display-name "Full App Unlock" --description "Unlock unlimited file uploads." --price "1.99" --base-territory "United States" --pretty
```

Metadata repair performed after setup:

```bash
asc iap review-screenshots create --iap-id 6769515889 --file docs/iap-review-screenshot.png --pretty
# The IAP availability record was subsequently set through the official ASC API
# for all 175 available territories, with new-territory availability enabled.
asc app-setup info set --app 6742799620 --primary-locale en-US --privacy-policy-url "https://github.com/janhcla/LANImageUploader/blob/main/PRIVACY.md" --pretty
```

Apple blocks standalone submission for the first IAP with `STATE_ERROR.FIRST_IAP_MUST_BE_SUBMITTED_ON_VERSION`; this IAP must be submitted together with the first App Store version.

## Trial Rules

- The trial counter starts when the first file upload completes successfully.
- LensBridge is free to try for 15 successful image/document uploads before requiring Full App Unlock.
- Failed uploads and duplicate-file prompts do not consume trial uploads.
- The successful upload count and purchased unlock state are stored in Keychain so uninstall/reinstall does not reset the trial.
- The premium override is stored in UserDefaults only for local/TestFlight
  validation. Debug builds enable it immediately. Release builds are production
  safe by default. Before each Xcode Cloud action,
  `ci_scripts/ci_pre_xcodebuild.sh` writes the channel into the existing
  `PremiumAccess.swift` source. Only workflow ID
  `37c9d62c-448d-4f60-8672-496a5c044c34` named
  `TestFlight - external beta test` writes `.testFlight`; missing or mismatched
  identity writes `.production` and therefore fails closed. The script's three
  controlled-input cases can be run with
  `scripts/test_xcode_cloud_distribution_gate.sh`.

## Code Map

- `PremiumAccess.swift`: trial state, Keychain persistence, and the
  deterministic build-channel premium override policy.
- `StoreKitPurchaseManager.swift`: StoreKit 2 product lookup, purchase, automatic entitlement refresh, and user-initiated restore. Restore calls `AppStore.sync()` and then verifies the current Full App Unlock entitlement.
- `FullAppUnlockView.swift`: paywall screen with price, one-time unlock, and an always-visible Restore Purchases action with result feedback.
- `UploadView.swift`: blocks upload when trial is exhausted and records each successful upload.
- `SettingsView.swift`: TestFlight-only override switch and Full App Unlock entry point.
- `LANImageUploaderTests.swift`: unit coverage for trial counting, developer unlock, purchased unlock, and exhausted-trial blocking.
