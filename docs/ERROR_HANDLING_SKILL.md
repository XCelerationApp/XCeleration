# XCeleration — Error Handling Standard

Read this when adding or modifying a service, controller, or screen that handles async data or operations.

---

## Philosophy

- Services convert exceptions into `Result<T>` — they never throw outward.
- Controllers unwrap results and set state — they never show dialogs or format strings.
- Widgets render state — they never catch exceptions.
- Programming errors (null dereferences, assertion failures) must not be swallowed. Let them surface.

---

## The Flow

```
Service / Repository  →  returns Result<T>
        ↓
Controller  →  unwraps Result<T>, sets state, logs with Logger
        ↓
Widget  →  reads hasError / error.userMessage, renders accordingly
```

---

## Result\<T\>

All service and repository methods return `Result<T>`. They never throw.

```dart
// lib/core/result.dart
sealed class Result<T> { const Result(); }

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}
```

---

## AppError

Separates the user-facing message from the raw exception. Never show `originalException` in the UI.

```dart
// lib/core/app_error.dart
final class AppError {
  const AppError({
    required this.userMessage,
    this.originalException,
  });

  /// Safe to display in the UI.
  final String userMessage;

  /// For logging only — never show to the user.
  final Object? originalException;
}
```

---

## Services — Catch and Return

```dart
Future<Result<List<Race>>> getRaces() async {
  try {
    final rows = await _db.query('races');
    return Success(rows.map(Race.fromMap).toList());
  } catch (e) {
    return Failure(AppError(
      userMessage: 'Could not load races. Please try again.',
      originalException: e,
    ));
  }
}
```

- Catch platform and SDK exceptions. Map them to `AppError` with a safe, generic user message.
- Do not catch `Error`, `AssertionError`, or other programming errors — let them surface.

---

## Controllers — Consume Results, Expose State

Every controller that loads data exposes:

```dart
bool _isLoading = false;
AppError? _error;

bool get isLoading => _isLoading;
bool get hasError => _error != null;
AppError? get error => _error;
```

Standard load method:

```dart
Future<void> loadRaces() async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  final result = await _raceRepository.getRaces();

  switch (result) {
    case Success(:final value):
      _races = value;
    case Failure(:final error):
      _error = error;
      Logger.e('[RacesController.loadRaces] ${error.originalException}');
  }

  _isLoading = false;
  notifyListeners();
}
```

For action methods (save, delete), return `AppError?` so the widget can decide how to present it:

```dart
Future<AppError?> deleteRace(int raceId) async {
  final result = await _raceRepository.deleteRace(raceId);
  return switch (result) {
    Success() => null,
    Failure(:final error) => error,
  };
}
```

- Use `Logger.e()` for errors, `Logger.d()` for debug — never `print`.
- Do not store `BuildContext` in a controller.
- Do not call `DialogUtils` from a controller.

---

## Widgets — Read State, Render

```dart
@override
Widget build(BuildContext context) {
  final controller = context.watch<RacesController>();

  if (controller.isLoading) return const AppLoadingWidget();

  if (controller.hasError) {
    return AppErrorWidget(
      message: controller.error!.userMessage,
      onRetry: controller.loadRaces,
    );
  }

  return _RacesContent(controller: controller);
}
```

For transient action errors, call `DialogUtils` in the widget after the await:

```dart
final error = await controller.deleteRace(race.raceId!);
if (error != null && mounted) {
  DialogUtils.showErrorDialog(context, message: error.userMessage);
}
```

---

## Checklist

- [ ] Service returns `Result<T>` — never throws outward
- [ ] `AppError.userMessage` is safe and generic — no SDK messages or stack traces
- [ ] Controller exposes `isLoading`, `hasError`, `error` for data loading
- [ ] Action methods return `AppError?` for caller-controlled error display
- [ ] Controller does not store `BuildContext` or call `DialogUtils`
- [ ] Widget reads state — no `try/catch` in `build` or listener methods
- [ ] `Logger.e()` used for all caught errors
- [ ] `flutter analyze` passes
