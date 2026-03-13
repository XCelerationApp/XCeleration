---
name: flutter-refactoring
description: >
  Flutter-specific refactoring guide for the XCeleration codebase. Use this skill
  whenever refactoring, cleaning up, or improving any existing Flutter/Dart file.
  Reference this before touching any controller, service, widget, or model.
---

# Flutter Refactoring Skill — XCeleration Codebase

Read this file fully before making any changes to existing code.

---

## Architecture Overview

XCeleration follows an MVVM-style architecture:

- Widgets render UI only
- Controllers contain business logic and state
- Services / Repositories handle data access and platform interaction
- Dependencies are constructor-injected
- Platform APIs are always wrapped behind abstractions

Only services and repositories require abstract interfaces. Controllers do not need interfaces unless consumed polymorphically.

---

## Process: The Order of Operations

For every file or feature you refactor, follow this sequence:

### Phase 1 — Identify Problems

- Scan for violations of the Non-Negotiables
- Identify large classes, long methods, deep nesting
- Define what "clean" looks like before touching code

### Phase 2 — Structural Refactor

> When modifying a service or controller, follow `skills/ERROR_HANDLING_SKILL.md` for error handling conventions.

- Refactor one concern at a time
- One logical change per commit (commit message describes the single concern changed)
- Do not mix structural changes with behavior changes
- Do not introduce new patterns mid-refactor

Run after every meaningful change:

```sh
flutter analyze
python3 scripts/test_runner.py
```

All three must pass before continuing. Note: If any of them fail and you are unsure whether the failure is caused by an incorrect refactor versus an intentional behavior change that has made the existing tests stale, stop and present this dilemma to the user, waiting for their decision before changing either the implementation or the tests. This is primarily for complex logic refactors.

### Phase 3 — Testing Pass

- Add or improve unit tests
- Cover all public methods
- Remove brittle or indirect tests
- Ensure no test hits real platform APIs

---

## Refactor Checklist (For Every File)

Before marking a module complete:

 [ ] All dependencies constructor-injected (→ Rule 2)

- [ ] No stored BuildContext (→ Rule 1)
- [ ] No new app-level singleton dependencies (→ Rule 3)
- [ ] No direct platform calls (→ Rule 5)
- [ ] No business logic inside widgets or `initState` (→ Rules 4, 7)
- [ ] Class under ~300 lines (or justified)
- [ ] Functions typically under 50 lines
- [ ] All public methods unit tested
- [ ] `flutter analyze` passes
- [ ] `python3 scripts/test_runner.py` passes

---

## Non-Negotiables — Never Leave These In Place

If a file contains these patterns and you cannot fix them immediately, flag them:

```dart
// TODO(refactor): explain violation and required fix
```

### 1. No BuildContext Stored in Controllers or Services

**Never do this:**

```dart
class MyController extends ChangeNotifier {
  late BuildContext _context; // FORBIDDEN
}
```

**Do this instead — pass context at call site:**

```dart
onPressed: () => controller.doSomething(context),

void doSomething(BuildContext context) {
  // use it here, never store it
}
```

Always check `.mounted` before using context after `await`.

---

### 2. No Concrete Instantiation Inside Classes

**Never do this:**

```dart
class RacesController {
  final _db = DatabaseHelper();
}
```

**Do this instead:**

```dart
class RacesController {
  final DatabaseHelper _db;

  RacesController({required DatabaseHelper db}) : _db = db;
}
```

All dependencies must come from outside the class. If you cannot swap it with a mock in tests, it is hardcoded.

---

### 3. No Static Calls or Singleton Dependencies

**Never do this:**

```dart
final user = AuthService.instance.user;
```

**Do this instead:** Inject the dependency.

If a legacy singleton is unavoidable:

- Wrap it behind an abstract interface
- Mark it clearly for migration
- Do not introduce new singleton usage

New code must never depend directly on singletons.

---

### 4. No Business Logic Inside Widgets

Widgets render. Controllers think.

**Never do this:**

```dart
Widget build(BuildContext context) {
  final sorted = results.sort(...);
}
```

**Do this instead:** Move computation to controller getters or methods.

Widgets may trigger controller logic, but may not contain logic.

---

### 5. No Direct Platform Calls

**Never do this:**

```dart
await SharedPreferences.getInstance();
```

**Do this instead:** Wrap in an injectable abstraction. All platform interaction must be mockable.

---

### 6. No Global Mutable State

**Never do this:**

```dart
var currentRaceId = 0;
```

Static Maps and caches count as global state. State must be scoped to a controller or service.

---

### 7. No Business Logic in Widgets (Including initState)

Widgets may trigger controller logic:

```dart
void initState() {
  super.initState();
  controller.onScreenReady();
}
```

But they must not:

- Perform async work directly
- Contain business decisions
- Access services directly

---

## Structural Rules

These are strong guidelines, not mechanical constraints.

### Function Length

- Target: under 50 lines
- Over 75 lines requires extraction or justification
- Extraction must improve clarity, not just reduce line count

### Class Length

- Target: under 300 lines
- Large classes must be decomposed gradually

### Parameters

- Avoid more than 5 parameters
- Use config objects if needed

### Nesting

- Avoid more than 4 indentation levels
- Extract complex conditionals

### Single Responsibility

If you must describe a class using "and," split it.

### Widget Decomposition

Extract a sub-widget when:

- A widget subtree has its own meaningful state or lifecycle
- A section of `build()` exceeds ~50 lines
- A subtree is reused in more than one place

Pass the controller (or specific fields) to sub-widgets; sub-widgets do not look up controllers themselves.

### Parallel Conditionals

Repeated switches on the same field indicate a modeling issue. Refactor toward polymorphism or data restructuring.

---

## Testing Standards

Follow `skills/TESTING_SKILL.md` for all testing conventions, mock setup, and examples.

Key rules that apply during refactoring:

- Every public method on a refactored class must have a unit test
- No test may touch a real database, network, or platform API
- Use injected mock dependencies — if you can't mock it, the dependency is hardcoded

---

## Migration Policy

- Never rewrite entire modules at once
- Migrate module-by-module using the strangler fig pattern
- Legacy singletons must not spread
- All new code must follow injection rules
- Technical debt must shrink, not move

---

## Definition of Done for a Refactored Module

- No violations of non-negotiables
- Constructor-injected dependencies
- Services have abstract interfaces
- No platform calls directly
- No logic in widgets
- Public methods fully unit tested
- Class size reasonable
- `flutter analyze` clean
- `python3 scripts/test_runner.py` clean
