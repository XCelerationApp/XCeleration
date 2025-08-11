# 10 — Reference: Event Bus

Last reviewed: 2025-08-11

Source: `lib/core/services/event_bus.dart`

## Usage

```dart
EventBus.instance.fire('event.type', data);
final sub = EventBus.instance.on('event.type', (event) {
  // handle
});
await sub.cancel();
```

## Event types

- race.created
- race.updated
- race.deleted
- race.flowState.changed
- results.updated
- runner.added
- runner.removed
- runner.updated
- tab.changed
- screen.changed
- device.connected
- device.disconnected
- device.dataReceived

## Payloads

- `race.flowState.changed`: `{ raceId: int, flowState: string }`
- Others follow conventional shapes for the affected entity
