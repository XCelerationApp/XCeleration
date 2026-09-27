# 08 — Build & Release

Last reviewed: 2025-08-11

## Android

- Build: `flutter build appbundle --release`
- Keystore: create and reference in `android/key.properties`; set signingConfigs in Gradle
- Play Store: upload AAB, populate store listing

## iOS

- Build: `flutter build ios --release` or Xcode Archive
- Signing: set team/profiles; consider Fastlane under `ios/fastlane`
- TestFlight/App Store: increment version/build, archive, upload

## Web

- Build: `flutter build web`
- Deploy: any static hosting; ensure correct base href in `web/index.html`

## Desktop

- Build: `flutter build macos|windows|linux`

## Versioning

- Update app/version in `pubspec.yaml`; platform build numbers per platform settings

## Release checklist

- [ ] Lints pass and tests green (including `test/integration/two_phone_sharing_test.dart`
      and `test/contract/wire_formats_test.dart`)
- [ ] Full real-phone rehearsal on the TestFlight build: [release-checklist.md](release-checklist.md)
- [ ] If anything phones send each other changed on purpose, its new format is
      saved (see `test/fixtures/wire/README.md`)
- [ ] Bumped versions and changelog
- [ ] Screenshots/metadata updated for stores
- [ ] Sentry checked for new issues
- [ ] dev -> main merged with **Create a merge commit**, never squash

## Troubleshooting

- iOS Cocoapods: `pod repo update && pod install`
- Android multidex/gradle sync: open in Android Studio
