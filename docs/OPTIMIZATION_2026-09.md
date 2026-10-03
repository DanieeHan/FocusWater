# FocusWater optimization — September 2026

## Product direction

SwiftUI remains the native implementation. A large, clear water bottle is the signature element; focus timing is the primary action and manual logging is secondary. No external design assets or component templates were introduced.

- Focus: visible accumulation, start/pause/save, confirmation before discarding a timer.
- Collection: completed bottles, accessible buttons and scrollable details.
- Activity: overview vs all sessions, note search, incremental display, CSV for analysis.
- Settings: preferences, honest iCloud state, local/cloud preference, full JSON backup/restore and in-app privacy explanation.

## Safety changes

- Explicit successful-save results keep the timer and manual-entry form intact on failure.
- Continuous elapsed time is used within a process; wall-time recovery is bounded and unusually long/negative intervals require review.
- Timer receipts prevent duplicate recording after an interrupted save; sub-minute remainder is retained.
- Failed writes roll back model changes, settings display and completion feedback.
- Recovery copies and hashes all store files before cleanup. Cleanup failure attempts to restore missing originals. The verified copy remains available even if rollback cannot finish.
- Portable JSON backups are validated before mutation; version, count, size, dates, durations, identifiers and relationships are checked. Restore merges missing IDs in one explicit save and preserves existing preferences.
- CSV notes cannot start spreadsheet formulas. Diagnostics omit raw error descriptions and full paths.
- Unsigned builds avoid CloudKit API startup. Demo/screenshot launches use an in-memory store, never the real database.
- The iCloud preference is local to each device and requires restart. Local and cloud modes use the same database URL; toggling never deliberately erases cloud records.

## Verification

- All 23 automated tests passed on an isolated iOS 26.5 simulator, including preservation of an unloaded timer on the database recovery screen.
- iOS simulator and iOS/macOS Release configurations compile with signing disabled; this is not a distribution archive.
- Visual checks: iPhone focus/add/activity/settings, English dark-mode history, maximum Dynamic Type focus layout, and iPad portrait focus layout. Found and fixed first-screen action overlap, narrow large-text headers, chart annotation overflow, and iPad two-column overflow.
- Not performed: full VoiceOver interaction, physical-device lock/relaunch, iPad landscape rotation, signed CloudKit synchronization or App Store upload.

Automated tests cover recording, edits, deletion, overflow, settings rollback, timer pause/resume/background/relaunch, elapsed clock changes, long-timer review, failed timer save, receipts, partial minutes, CSV safety, backup round trips/repeated imports/invalid files/save failure, cloud fallback URL/local preference, recovery copy failures and diagnostic redaction.

Visual QA uses a separate simulator with synthetic in-memory records. This is not a substitute for VoiceOver, keyboard, real-device or multi-account CloudKit testing.

## Main implementation files

- `Views/FocusTab/FocusView.swift`: bottle-led layout, timer controls, accessible layout and reset confirmation.
- `Views/FocusTab/AddFocusSheet.swift`: compact form, arbitrary minute selection, retained failed entries.
- `Views/SettingsView.swift`: preferences vs Data & Privacy, sync preference and backup flows.
- `Models/FocusTimer.swift`: serializable local timer state and injectable elapsed clock.
- `Models/FocusBackup.swift`: versioned, size-bounded backup format and validation.
- `ViewModels/FocusViewModel.swift`: transactional writes, timer receipts, partial-minute retention, merge restore and cloud-event refresh.
- `AppStoreCoordinator.swift`: startup fallback, verified recovery copies and sanitized diagnostics.
- `FocusWaterTests/FocusViewModelTests.swift`: deterministic regression and fault-injection coverage.

## Release gates still requiring real-world verification

1. Set the intended signing team and final identifiers; produce a signed archive and inspect the privacy report.
2. Exercise iCloud login/logout, account A to B switching, network loss/recovery, simultaneous edits on two devices, production CloudKit schema and delayed imports. Do not describe account availability as successful synchronization.
3. Verify an existing on-disk store upgrades with the additive optional timer receipt field, using copies of release-era databases.
4. Check small iPhone, iPad portrait/landscape, macOS, VoiceOver, maximum Dynamic Type and Reduce Motion. Finish platform-specific sandbox/signing decisions before Mac App Store distribution; do not relocate existing stores without migration.
5. Replace the support-email placeholder and publish the privacy policy; refresh store screenshots after UI approval.
6. Create the first reviewed Git commit. No commit was created automatically by this optimization.

## Technical boundaries

No developer backend, account system, analytics, ads or notification permission requests were added. No real user database was reset or imported during testing. Exported backups are readable JSON, not encrypted archives. Raw recovery-store files may still need manual recovery; JSON import is not an importer for corrupt SQLite files. Full multi-device conflict reconciliation and cryptographic app-lock features are not claimed complete.

## Apple implementation references

- [SwiftData synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Observing sync and remote-store events](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)
- [Platform data protection classes](https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web)
