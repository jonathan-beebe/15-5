# 15-5

A focus timer for macOS, iOS, and iPadOS. Fifteen minutes of focus, five of break, on repeat.
Both lengths are adjustable. Each phase change plays a chime; on macOS it also washes every
display in the phase color, and on iOS a local notification carries the alert while the app is
in the background.

## Requirements

- Xcode 27
- macOS 14 or iOS 17 to run

## Setup

```sh
make setup
```

Checks for Xcode and shellcheck and creates `Config/Local.xcconfig` from its example. Set
`APP_BUNDLE_ID` and `DEVELOPMENT_TEAM` there. Git ignores the file. Debug builds for macOS and
the Simulator work without a team. Release builds, device runs, and releases need one.

## Commands

`make` lists every target. Each one wraps a script under `scripts/`, which holds the logic.

```sh
make run              # Debug build to dist/15-5.app, then launch it, replacing a running copy
make demo             # the same, launched with a 6 s / 4 s cycle already running
make test             # tests on macOS, then on an iOS Simulator (SIMULATOR=<name or UDID>)
make check            # shellcheck, both test runs, and unsigned Release builds for both platforms
make clean            # remove build/, dist/, and this project's DerivedData (DRY_RUN=1 lists only)
```

Full xcodebuild output goes to `build/logs/`. The terminal shows diagnostics, test results,
and the verdict.

Debug builds add a Developer menu on macOS and accept the `-demo` launch argument. Release
builds have neither.

## Release

The version and build number live in `Config/Base.xcconfig`, and a release is built from a
`vX.Y.Z+##` tag on HEAD that agrees with that file. `##` is the build number, by default the
date and time of the cut as `YYYYMMDDHHMM`. App Store Connect refuses a build number at or
below the last upload for a version, and a review rejection is fixed by a new build of the same
version, so each cut gets a higher number on its own.

```sh
make set-version VERSION=1.0.0 TAG=1   # write Config/Base.xcconfig, commit it, tag v1.0.0+<build>
make release-dry-run                   # preflight, archive, export, validate, for both platforms
make release                           # the same, then upload to App Store Connect
```

`make set-version` without `TAG=1` writes the file and prints the commit and tag commands, to
review the diff first. `BUILD=##` sets an explicit build number.

Preflight is read-only and reports every problem at once: a missing or malformed tag, a tag
that disagrees with `Config/Base.xcconfig`, uncommitted changes, no team, and missing
credentials. Under `make release-dry-run` a missing credential is a warning, and the steps that
need it are skipped.

The release signs with the App Store Connect API key named in `scripts/release-config.sh`,
read from `~/.appstoreconnect/private_keys/`. xcodebuild uses it to manage provisioning
profiles and altool to validate and upload, so no Xcode account sign-in is involved. The
keychain needs the Apple Distribution and 3rd Party Mac Developer Installer certificates for
the team. Artifacts land in `dist/` as `15-5-<version>+<build>-macOS.pkg` and `-iOS.ipa`.

The app makes no network connections, collects no data, and uses no encryption, so uploads skip
the export compliance question (`ITSAppUsesNonExemptEncryption` is false in `Info.plist`).
`PrivacyInfo.xcprivacy` declares the UserDefaults and elapsed-time API reasons.

After the upload, App Store Connect processes each build before it appears under TestFlight.
A build that never appears was rejected in processing, and Apple emails the account holder the
reason. Validation does not catch everything processing does.

### App Store Connect checklist

Per platform, once:

- An app record for the bundle ID, with the macOS and iOS apps sharing one record.
- Screenshots: a Mac at 1280×800 or larger, an iPhone at 6.9" or 6.5", and an iPad at 13".
- Privacy nutrition label: Data Not Collected.
- Age rating questionnaire.
- Review notes: the macOS app replaces its Dock icon while running and covers every display for
  four seconds at each phase change. The iOS app asks for notification permission on the first
  Play.

## Layout

| Path | Contents |
| --- | --- |
| `FifteenFive/` | App sources. `PlatformSession.*.swift` hold the per-platform effects. |
| `FifteenFiveTests/` | Swift Testing suites. `RecordingSession` stands in for the platform. |
| `Config/` | Build settings: versions, bundle ID, team. |
| `scripts/` | The commands behind the Makefile, plus generators for the app icon and the chime. |
