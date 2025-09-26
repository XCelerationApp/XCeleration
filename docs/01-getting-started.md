# 01 — Getting Started

Last reviewed: 2025-08-11

This is the canonical setup guide for developing and running the app.

## Supported versions

- Flutter: stable channel (recommend latest stable)
- Dart: bundled with Flutter stable
- iOS: Xcode 15+, iOS 15+
- Android: Android Studio Iguana+, minSdk per `android/app/build.gradle`
- Desktop: latest stable toolchains for macOS/Windows/Linux

## Prerequisites

- Flutter SDK and platform toolchains installed and on PATH
- CocoaPods for iOS: `sudo gem install cocoapods`
- Android Studio with Android SDKs

Verify:

```bash
flutter --version
dart --version
```

## Environment configuration (.env)

Create `.env` at repo root:

```dotenv
APP_NAME=Race Timer
SENTRY_DSN=
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
```

- Missing `SUPABASE_*` disables remote sync gracefully.
- `APP_NAME` appears in UI.

## Install dependencies

```bash
flutter pub get
```

For iOS:

```bash
cd ios && pod install && cd -
```

## Run targets

```bash
flutter run                  # auto-detects a device
flutter run -d ios           # iOS Simulator
flutter run -d android       # Android Emulator
flutter run -d chrome        # Web
flutter run -d macos         # macOS
flutter run -d windows       # Windows
flutter run -d linux         # Linux
```

On first launch, choose a role on `lib/shared/role_screen.dart`.

## Multi-device local test

Goal: verify connectivity and a simple transfer.

1. Launch two emulators/simulators or devices.
2. On Device A, choose role Coach. On Device B, choose role Bib Recorder (or Race Timer).
3. Ensure Bluetooth/Location permissions are granted.
4. From the Coach screen, start discovery/advertising as applicable.
5. Send a small payload (e.g., sample bibs) and observe logs for `DATA/ACK/FIN`.

Tips:

- If discovery fails, toggle airplane mode or restart Nearby (app restart often helps).
- Check logs via `lib/core/utils/logger.dart` to see protocol steps.

## Troubleshooting (quick)

- iOS pods: `pod repo update && pod install`
- Android Gradle sync: open in Android Studio once
- Web base href/CORS: ensure correct path in `web/index.html`
- Permissions: enable Bluetooth/Location

See [08-dev/build-and-release.md](08-dev/build-and-release.md) and [04-connectivity/protocol.md](04-connectivity/protocol.md) for deeper issues.
