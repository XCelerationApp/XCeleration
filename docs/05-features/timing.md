# 05 — Feature: Race Timer

Last reviewed: 2025-08-11

## Code

- Controller: `assistant/race_timer/controller/timing_controller.dart`
- State: `assistant/race_timer/model/timing_data.dart`
- UI: `assistant/race_timer/screen/timing_screen.dart`, `assistant/race_timer/widgets/**`

## Flow (high level)

1. Start race; controller begins capturing finish timestamps
2. Resolve conflicts where needed
3. Package timing data for transfer to Coach via protocol

## Sample

```dart
// Pseudocode: sending timing data
// protocol.handleDataTransfer(deviceId: coachId, dataToSend: encodedTiming, isReceiving: false, shouldContinueTransfer: () => mounted);
```

## Tips

- Use hot reload during iteration
- Watch logs for chunk counts and ACKs during transfer
