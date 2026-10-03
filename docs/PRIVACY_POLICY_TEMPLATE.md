# FocusWater Privacy Policy

Draft updated: September 12, 2026 — confirm the effective date before publishing.

FocusWater is designed to keep your focus records private.

## Data stored by the app

FocusWater stores focus-session dates, durations, optional notes, bottle progress, and app preferences. This information is used only to provide the app's focus tracking, archive, statistics, and settings features.

## iCloud synchronization

When enabled and available, FocusWater synchronizes app data with the private CloudKit database associated with your Apple ID. The app does not send focus records to a developer-operated server. You can change the iCloud preference in Settings; it takes effect on the next app launch. Disabling sync does not delete existing iCloud copies. Local storage remains available when cloud initialization fails. Account availability is not a guarantee that every record has finished syncing.

## Data collection and tracking

FocusWater does not include advertising, third-party analytics, or tracking SDKs. The app does not sell personal information and does not require a separate FocusWater account.

## Data control

You can edit or delete individual sessions, export CSV for analysis, and export or restore a versioned JSON backup containing sessions, notes, bottles, and preferences. Restore adds missing record identifiers and does not overwrite existing records. These exported files are not password encrypted; anyone with access to them can read their contents. Choose a trusted destination and manage or delete exported copies there.

The app keeps unfinished timer state in local preferences so it can recover after a restart. Timer state is not synchronized between devices. The device operating system protects the app's local storage; use a device passcode and appropriate account security. The app does not provide a separate app-lock or a promise of end-to-end encryption.

If the database cannot be opened, you can explicitly choose to rebuild it. The app first copies and verifies the database files and retains the recovery copy in its local data area. Unsynchronized records may need manual recovery from that copy. Do not uninstall the app during recovery: uninstalling may remove both active local data and local recovery copies. Data synchronized through iCloud is governed by your Apple ID and iCloud settings.

Diagnostic exports contain app/OS versions and sanitized error categories/codes. They exclude session content, notes, account identifiers, and absolute filesystem paths. They are exported only when you request it and are not automatically uploaded.

## Changes

This policy may be updated when the app's data practices change. The effective date above will be updated when a revised policy is published.

## Contact

Questions about this policy can be sent to: **[REPLACE WITH SUPPORT EMAIL]**

Before publishing, replace the contact placeholder, host this document at a public HTTPS URL, and enter that URL in App Store Connect.
