# Premium Feature Skeleton

## App Store Connect

- App Store Connect app ID: `6742799620`
- Bundle ID: `com.janhagenclausen.LANImageUploader`
- In-app purchase ID: `6769515889`
- Product ID: `com.janhagenclausen.LANImageUploader.fullunlock`
- Type: non-consumable
- Display name: `Full App Unlock`
- Price: `USD 1.99`
- Review screenshot ID: `c365aac8-058d-469e-af1d-d723cf4b099c`
- Availability: United States, with automatic availability in new territories enabled
- Current ASC state after metadata repair: `READY_TO_SUBMIT`

Created and verified with:

```bash
asc iap setup --app 6742799620 --type NON_CONSUMABLE --reference-name "Full App Unlock" --product-id "com.janhagenclausen.LANImageUploader.fullunlock" --locale en-US --display-name "Full App Unlock" --description "Unlock unlimited file uploads." --price "1.99" --base-territory "United States" --pretty
```

Metadata repair performed after setup:

```bash
asc iap review-screenshots create --iap-id 6769515889 --file docs/iap-review-screenshot.png --pretty
asc iap pricing availability set --iap-id 6769515889 --territories "United States" --available-in-new-territories --pretty
asc app-setup info set --app 6742799620 --primary-locale en-US --privacy-policy-url "https://github.com/janhcla/LANImageUploader#privacy" --pretty
```

Apple blocks standalone submission for the first IAP with `STATE_ERROR.FIRST_IAP_MUST_BE_SUBMITTED_ON_VERSION`; this IAP must be submitted together with the first App Store version.

## Trial Rules

- The trial counter starts when the first file upload completes successfully.
- The app allows 15 successful file uploads before requiring Full App Unlock.
- Failed uploads and duplicate-file prompts do not consume trial uploads.
- The successful upload count and purchased unlock state are stored in Keychain so uninstall/reinstall does not reset the trial.
- Developer Mode is stored in UserDefaults and only simulates Full App Unlock for local testing.

## Code Map

- `PremiumAccess.swift`: trial state, Keychain persistence, developer unlock toggle, and product constants.
- `StoreKitPurchaseManager.swift`: StoreKit 2 product lookup, purchase, and entitlement sync skeleton.
- `FullAppUnlockView.swift`: paywall screen with price and one-time unlock button.
- `UploadView.swift`: blocks upload when trial is exhausted and records each successful upload.
- `SettingsView.swift`: Developer Mode switch and Full App Unlock entry point.
- `LANImageUploaderTests.swift`: unit coverage for trial counting, developer unlock, purchased unlock, and exhausted-trial blocking.
