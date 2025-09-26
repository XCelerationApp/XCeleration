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

- [ ] Lints pass and tests green
- [ ] Protocol/basic transfer sanity on two devices
- [ ] Bumped versions and changelog
- [ ] Screenshots/metadata updated for stores

## Troubleshooting

- iOS Cocoapods: `pod repo update && pod install`
- Android multidex/gradle sync: open in Android Studio
