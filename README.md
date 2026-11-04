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
cp Config/Local.example.xcconfig Config/Local.xcconfig
```

Set `APP_BUNDLE_ID` and `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`. Git ignores the file.
Debug builds for macOS and the Simulator work without a team. Release builds, device runs, and
archives need one.

## Build and test

```sh
xcodebuild -project 15-5.xcodeproj -scheme 15-5 -destination 'platform=macOS' test
xcodebuild -project 15-5.xcodeproj -scheme 15-5 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

Debug builds add a Developer menu on macOS and accept a `-demo` launch argument, which starts a
6 s / 4 s cycle on launch. Release builds have neither.

## Release

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. App Store
   Connect rejects an upload whose build number it has already seen for that version.
2. Archive each platform. In Xcode: Product > Archive with the destination set to
   My Mac, then again with Any iOS Device. From the shell:

   ```sh
   xcodebuild archive -project 15-5.xcodeproj -scheme 15-5 \
     -destination 'generic/platform=macOS' -archivePath build/15-5-macOS.xcarchive
   xcodebuild archive -project 15-5.xcodeproj -scheme 15-5 \
     -destination 'generic/platform=iOS' -archivePath build/15-5-iOS.xcarchive -allowProvisioningUpdates
   ```

3. Upload each archive from Xcode's Organizer with Distribute App > App Store Connect, or
   export with `xcodebuild -exportArchive` and a plist whose `method` is `app-store-connect`.
   Signing is automatic. The macOS export needs the 3rd Party Mac Developer Installer
   certificate in the keychain, and the iOS export needs an Apple Distribution certificate.
   The iOS export runs `rsync` from `PATH` and fails with "Copy failed" under Homebrew's
   rsync, so run it with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`.

The app makes no network connections, collects no data, and uses no encryption, so uploads skip
the export compliance question (`ITSAppUsesNonExemptEncryption` is false in `Info.plist`).
`PrivacyInfo.xcprivacy` declares the UserDefaults and elapsed-time API reasons.

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
| `scripts/` | Generators for the app icon and the chime. |
