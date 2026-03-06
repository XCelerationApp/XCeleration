# XCeleration — Testing Standard

Read this when writing or modifying any test file.

---

## Philosophy

- Test **behavior**, not implementation details.
- Test **public APIs only** — never call private methods directly.
- Tests must be **deterministic** — same input, same result, every run.
- One behavior per `test()` call — never assert unrelated things together.

---

## Stack

- **Test framework:** `flutter_test`
- **Mocking:** `mockito` with `@GenerateMocks` + `build_runner`
- **Architecture under test:** Controllers → Services → DatabaseHelper / Supabase

---

## Folder Structure

Mirror the `lib/` structure inside `test/`, organized by type first.

```
test/
├── unit/
│   ├── coach/
│   ├── assistant/
│   └── core/
├── widget/
│   └── coach/
└── integration/
```

- All test files end in `_test.dart` and match the file they test.
- Generated mock files (`*.mocks.dart`) live alongside the test that declares them.

---

## Layer Boundaries

Each layer mocks the layer directly below it. Nothing reaches through layers.

```
Controller tests  →  mock Services
Service tests     →  mock DatabaseHelper / Supabase client
Widget tests      →  mock Controllers
```

No test may hit a real database, network, or platform API.

---

## Mocking with Mockito

Declare mocks with `@GenerateMocks` and regenerate with `build_runner` after changes.

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'races_controller_test.mocks.dart';

@GenerateMocks([RacesService])
void main() { ... }
```

Register fallback values in `setUpAll` for any custom types used as arguments:

```dart
setUpAll(() {
  registerFallbackValue(Race(raceName: ''));
});
```

---

## Controller Tests

Controllers extend `ChangeNotifier`. Test that they correctly translate `Result<T>` from services into state.

```dart
void main() {
  late RacesController controller;
  late MockRacesService mockService;

  setUp(() {
    mockService = MockRacesService();
    controller = RacesController(service: mockService);
  });

  group('RacesController', () {
    group('loadRaces', () {
      test('sets races and clears error on Success', () async {
        final races = [Race(raceName: 'State Meet')];
        when(mockService.getRaces()).thenAnswer((_) async => Success(races));

        await controller.loadRaces();

        expect(controller.races, equals(races));
        expect(controller.hasError, isFalse);
        expect(controller.isLoading, isFalse);
      });

      test('sets error on Failure', () async {
        when(mockService.getRaces()).thenAnswer(
          (_) async => Failure(AppError(userMessage: 'Could not load races.')),
        );

        await controller.loadRaces();

        expect(controller.hasError, isTrue);
        expect(controller.error!.userMessage, 'Could not load races.');
        expect(controller.isLoading, isFalse);
      });
    });
  });
}
```

---

## Service Tests

Services wrap database or SDK calls and return `Result<T>`. Test that exceptions are caught and mapped — never expect them to throw.

```dart
void main() {
  late RacesService service;
  late MockDatabaseHelper mockDb;

  setUp(() {
    mockDb = MockDatabaseHelper();
    service = RacesService(db: mockDb);
  });

  group('RacesService', () {
    group('getRaces', () {
      test('returns Success with races on valid query', () async {
        when(mockDb.query('races')).thenAnswer((_) async => [
          {'race_id': 1, 'race_name': 'State Meet'},
        ]);

        final result = await service.getRaces();

        expect(result, isA<Success<List<Race>>>());
        expect((result as Success).value.first.raceName, 'State Meet');
      });

      test('returns Failure when database throws', () async {
        when(mockDb.query('races')).thenThrow(Exception('db error'));

        final result = await service.getRaces();

        expect(result, isA<Failure<List<Race>>>());
      });
    });
  });
}
```

`thenThrow` is only acceptable at the service level to simulate a genuine platform exception. Controllers must never use `thenThrow`.

---

## Widget Tests

Widget tests verify that the correct UI renders for a given controller state. Mock the controller and set state directly.

```dart
testWidgets('shows error widget when hasError is true', (tester) async {
  final controller = MockRacesController();
  when(controller.isLoading).thenReturn(false);
  when(controller.hasError).thenReturn(true);
  when(controller.error).thenReturn(AppError(userMessage: 'Something went wrong.'));

  await tester.pumpWidget(
    ChangeNotifierProvider<RacesController>.value(
      value: controller,
      child: const MaterialApp(home: RacesScreen()),
    ),
  );

  expect(find.text('Something went wrong.'), findsOneWidget);
});
```

---

## What Not to Test

- Trivial model constructors with no logic
- Simple getters and setters
- Flutter framework behavior (e.g. that `Text` renders text)
- Private methods or helpers — if a private method seems to need testing, extract it into its own class
- Third-party library internals

---

## General Rules

- Use `setUp()` to initialize the class under test and all mocks before each test.
- Use `group()` to organize by class, then by method.
- Name tests as plain statements: `'returns Failure when database throws'`, not `'test failure'`.
- Use `async`/`await` directly — never `Future.delayed` in tests.
- For time-sensitive code (timers, debounces), use `fakeAsync`.

---

## Running Tests

Always use the custom runner — output fits in a single Bash tool read:

```sh
python3 scripts/test_runner.py                        # all tests
python3 scripts/test_runner.py path/to/test.dart     # single file
python3 scripts/test_runner.py test/unit/            # whole folder
python3 scripts/test_runner.py -v [targets...]       # verbose: full stack traces, no line truncation
```

Do NOT run `flutter test` directly — its raw output exceeds the Bash tool's readable limit.

Use `-v` when the default output truncates the error and more context is needed.

---

## Checklist

- [ ] Test file mirrors `lib/` path under `test/unit/`, `test/widget/`, or `test/integration/`
- [ ] Mocks declared with `@GenerateMocks` — no manual mock classes
- [ ] Controller tests assert on `isLoading`, `hasError`, and state after each action
- [ ] Service tests assert on `Result<T>` — never on thrown exceptions
- [ ] No test touches a real database, network, or platform API
- [ ] `python3 scripts/test_runner.py` passes
