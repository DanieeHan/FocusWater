# FocusWater

**English** | [简体中文](README.zh-CN.md)

Turn every moment of focus into a bottle of clear water.

FocusWater is a native SwiftUI focus tracker for iPhone, iPad, macOS, and Mac Catalyst. Records are stored locally with SwiftData, with optional synchronization through a private CloudKit database.

This is a pre-release development snapshot. GitHub source publication and App Store submission are separate steps; physical-device iCloud behavior, multi-device conflicts, and migration from older databases still require verification.

## Features

- **Focus:** bottle progress, start/pause timing, manual logging, cross-midnight date accounting, and retention of sub-minute timer remainder.
- **Collection:** completed bottles and their associated records.
- **Activity:** weekly trends, streaks, a three-month heatmap, search, editing, deletion, and CSV export.
- **Settings:** goals, language, appearance, iCloud preference, and versioned JSON backup/merge restore.
- Failed saves preserve form input and timer state. Database startup errors offer retry, diagnostic export, and rebuild after a verified backup.
- Simplified Chinese and English, light/dark appearance, and Dynamic Type layouts.

## Requirements

- Xcode 16 or later; the previous full verification used Xcode 26.6.
- iOS / iPadOS 17+, macOS 14+.
- No third-party Swift package dependencies.
- The standalone model test script requires `ripgrep` (`rg`) to collect source files.

Open `FocusWater.xcodeproj`, select the `FocusWater` scheme, and choose a simulator. Physical-device and iCloud testing require your own development team, bundle identifier, and CloudKit container. The current identifiers are `com.hanzibo.FocusWater` and `iCloud.com.hanzibo.FocusWater`.

## Build and test

These commands assume Xcode is installed at `/Applications/Xcode.app` and its first-launch setup and license acceptance are complete:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild build \
  -project FocusWater.xcodeproj \
  -scheme FocusWater \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -showdestinations \
  -project FocusWater.xcodeproj \
  -scheme FocusWater

# Replace SIMULATOR_UUID with an iOS simulator ID listed above.
xcodebuild test \
  -project FocusWater.xcodeproj \
  -scheme FocusWater \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  CODE_SIGNING_ALLOWED=NO
```

All 23 automated tests passed during the previous verification, covering timer recovery, duplicate-save protection, write rollback, backup validation, database recovery, and diagnostic redaction. Builds and tests were not rerun during GitHub publication preparation because the local Xcode 27 installation still required license acceptance.

## Data and privacy

The app has no developer-operated backend, advertising, third-party analytics SDKs, or notification permission requests. Optional iCloud synchronization uses the private database associated with the user's Apple ID; preference changes take effect on the next launch. CSV and JSON exports contain readable notes and should be stored securely.

Do not include personal records, databases, backups, account information, or signing files in issues, screenshots, or commits. The [privacy policy draft](docs/PRIVACY_POLICY_TEMPLATE.md) still needs contact information and public hosting before App Store submission.

## Project structure

```text
FocusWater/
  Models/          Data models, timer state, and backup format
  ViewModels/      Timing, persistence, statistics, and sync status
  Views/           Focus, Collection, Activity, and Settings screens
  Resources/       App icons and privacy manifest
  AppStoreCoordinator.swift  Data-container startup and recovery
FocusWaterTests/   Regression and fault-injection tests
docs/             Development notes, privacy draft, and release materials
```

`generate_project.py` is a legacy generator that does not preserve the complete current project configuration. Edit the existing Xcode project for normal development.

Historical marketing screenshots remain local and are excluded from the initial source publication. Their UI needs updating before store use. Production app icons are included in the repository.

## Release documentation

- [Optimization notes and verification boundaries](docs/OPTIMIZATION_2026-09.md)
- [App Store launch checklist](docs/APP_STORE_LAUNCH_CHECKLIST.md)
- [GitHub publication preparation (Chinese)](docs/GITHUB_RELEASE_PREPARATION.md)

## License

This project uses the custom [FocusWater Source-Available License](LICENSE). You may view, study, fork, and modify the source, and build it privately for your own use. Source-only redistribution must retain the license and copyright notice.

**Publishing, listing, selling, or distributing original or modified apps requires the author's prior written permission, including free distribution, external TestFlight testing, installer downloads, and third-party hosted services. Renaming, rebranding, or modifying the code does not remove this restriction.**

This is a source-available project with an app-distribution restriction. The complete terms in `LICENSE` govern use.

## Project demo

Bottles accumulate across days, while daily statistics follow record dates. See the [demo guide](docs/DEMO.md) (Chinese) for product rules, a two-minute walkthrough and technical talking points.

### Local validation on October 4, 2026

`sh scripts/test-timer-accounting.sh` passed 12 regression scenarios and 1,000 duration-conservation cases. Production Swift sources typechecked for macOS Release/DEBUG and iOS Simulator DEBUG. The standalone macOS runner executed all 33 XCTest cases against the production models, with zero failures, including cross-midnight accounting, pause/relaunch, failed-save retry, remainder snapshots and historical bottles. iOS Simulator XCTest has not been run. Signed builds, physical devices and CloudKit behavior were not validated in this pass.

Run `sh scripts/test-model-macos.sh` for real model regressions (requires the installed Xcode compiler and SDK). It uses temporary build files and isolated in-memory or temporary on-disk databases without launching the app.

### Follow-up validation on October 5, 2026

The documented `sh` entry point now switches to Bash when required. All 35 macOS XCTest cases passed, including two added checks for deleting the latest bottle and reopening a temporary on-disk SwiftData store with dates, timer receipts, and remainder intact. Timer accounting again passed all 12 scenarios and 1,000 conservation cases; production iOS Simulator DEBUG source typechecking also passed. The disk test covers the current schema, not migration from a historical release. See the [remaining acceptance steps](docs/VALIDATION_2026-10-05.md) (Chinese).
