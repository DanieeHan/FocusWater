# FocusWater App Store Launch Checklist

## Current status

- Universal target is enabled for `iPhone`, `iPad`, `macOS`, and `Mac Catalyst`.
- Local persistence uses `SwiftData`.
- The first release does not request notification permission.
- A starter `PrivacyInfo.xcprivacy` file exists and matches the current no-tracking/no-third-party-analytics implementation; verify it again from the final archive.
- The app icon catalog now contains generated iOS and macOS artwork, including a separate 1024x1024 marketing export at `marketing/AppIcon-1024.png`.
- Focus sessions can now be edited, deleted, and exported as CSV.
- Twenty-three unit tests cover bottle overflow, goal changes, editing/deletion, timer persistence and failed saves, backup validation/merge/rollback, recovery-file failures, local/cloud preference behavior, and export privacy.
- September optimization adds a bottle-led adaptive focus page, Activity overview/history, searchable notes, and a dedicated Data & Privacy settings category. See `OPTIMIZATION_2026-09.md`.

## Hard blockers before submission

### 1. Final app icon review

- Review the generated icon artwork in `FocusWater/Resources/Assets.xcassets/AppIcon.appiconset/` and replace it only if a commissioned final design is preferred.
- Verify the icon renders correctly on:
  - iPhone
  - iPad
  - macOS
- Keep a separate flattened 1024x1024 export for App Store marketing use.

### 2. Privacy policy and App Privacy details

- Replace the support-email placeholder in `docs/PRIVACY_POLICY_TEMPLATE.md`, publish it, and prepare the public `Privacy Policy URL`.
- In App Store Connect, complete the App Privacy questionnaire.
- Confirm whether the app collects any user-linked data, analytics, crash data, or tracking data.
- Re-check `PrivacyInfo.xcprivacy` using Xcode's privacy report before archiving.

### 3. Store listing assets

- Prepare app name, subtitle, keywords, and description.
- Prepare screenshots for each platform you plan to ship:
  - iPhone
  - iPad
  - macOS
- Optional but recommended: app preview videos.

### 4. Apple account and signing

- Set a valid `Development Team` in Xcode.
- Confirm the final `Bundle ID`.
- Confirm `Marketing Version` and `Build Number`.
- Verify you can create an `Archive`.

### 5. App Store Connect required metadata

- Age rating
- Category
- Privacy Policy URL
- Copyright
- Support URL
- App review contact information

## Product quality gaps worth fixing before review

### Data safety and stability

- Test `SwiftData` migration from older local stores.
- Completed: CSV analysis export plus versioned JSON backup/merge restore. Exported files are readable and contain notes; review the in-app privacy explanation.
- Completed: retry/diagnostics/verified-backup-before-rebuild recovery flow. Raw database recovery may still require manual assistance.
- Pending: signed real-device iCloud login/logout, account switching, network recovery and simultaneous two-device edits. Mocked startup fallback tests do not cover real CloudKit behavior.
- Completed: editing and deletion for incorrect focus records.

### Cross-platform QA

- Run through the full flow on:
  - iPhone
  - iPad
  - macOS
- Check compact-width layouts, sheet behavior, and tab usability.

### Review risk reduction

- Confirm all user-facing text is localized consistently in Chinese and English.
- Confirm no placeholder art or placeholder wording remains.

## Suggested submission order

1. Finish icons and screenshots.
2. Verify privacy answers and update `PrivacyInfo.xcprivacy`.
3. Run TestFlight/internal device testing.
4. Create archive and upload to App Store Connect.
5. Fill product page metadata and submit for review.

## Useful official references

- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Configure app icon: https://developer.apple.com/documentation/xcode/configuring-your-app-icon
- Add an app icon in App Store Connect help: https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/
- Upload screenshots and previews: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
