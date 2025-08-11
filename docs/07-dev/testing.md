# 07 — Testing

Last reviewed: 2025-08-11

## Commands

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
```

## Structure

- Unit tests: `test/unit/**`
- Integration tests: `test/integration/**`
- Widget tests: `test/widget/**`

## Conventions

- Use Mockito `@GenerateMocks` and run build_runner for mocks
- Keep tests deterministic; seed DB through helpers when needed

## Example snippet

```dart
// Subscribe to an event in tests
final sub = EventBus.instance.on(EventTypes.resultsUpdated, (e) {
  expect(e.data, isNotNull);
});
// ... fire event and await ...
await sub.cancel();


