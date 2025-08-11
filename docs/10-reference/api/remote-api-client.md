# 10 — Reference: Remote API Client (Supabase)

Last reviewed: 2025-08-11

Source: `lib/core/services/remote_api_client.dart`

## Init

```dart
await RemoteApiClient.instance.init();
if (!RemoteApiClient.instance.isInitialized) {
  // remote disabled
}
```

## Usage

```dart
final client = RemoteApiClient.instance.client;
await client.from('runners').select();
```

## Notes

- If keys missing, `init()` leaves client uninitialized; sync skips gracefully
