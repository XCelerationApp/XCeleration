# XCeleration App — Current State Assessment

> **Snapshot as of 2026-02-28 — not authoritative, will go out of date as refactoring progresses.**

---

## What's Built and Working

### Coach Role

- Race creation and management (name, date, location, distance, flow state)
- Runner roster management: manual entry plus import from CSV, Excel, and Google Sheets
- Full multi-step race flow: Setup → Pre-Race (share with assistants) → Post-Race (collect results) → Finished
- Wireless P2P data sharing with assistant devices (Apple Multipeer / Android Nearby Connections)
- Merge conflict resolution when multiple assistants return overlapping timing data
- Bib number conflict resolution screen
- Race results view with individual times, team scoring, head-to-head, and averages
- Export/share via PDF, Google Sheets, QR code, and spectator broadcast URL
- Offline-first local storage (SQLite via `DatabaseHelper`) with Supabase remote sync (push/pull, LWW conflict resolution)
- Google sign-in via Supabase auth

### Assistant Role

- **Timer sub-role**: one-tap finish logging with haptic + audio feedback, marking missing/extra times, encoding data for coach
- **Bib Recorder sub-role**: bib number entry with roster validation, duplicate/unknown flagging, encoding data for coach
- Onboarding coach-mark tutorials on both assistant screens
- Reconnection logic and cancellation token handling in `DeviceConnectionService`

### Spectator Role

- Join a coach via QR code or manual add-coach flow
- Receive live race broadcast and view results (live or final)

### Infrastructure

- `MasterRace` lazy-loading cache/facade keyed by race ID
- `AssistantStorageService` (separate SQLite DB for assistant role)
- `SyncService` with dirty-flag tracking and per-record push/pull
- Settings and auth screens
- Custom page route animations
- Theme system

---

## What's Partially Built or Broken

### MasterRace Listener Disabled

The `_masterRaceListener` in [race_screen_controller.dart](coach/race_screen/controller/race_screen_controller.dart) is commented out with the note "temporarily disabling to prevent infinite loops." The listener field is `// ignore: unused_field`. A data-refresh loop was suppressed rather than fixed; background data updates no longer propagate to the race screen automatically.

### `features/` Directory — Incomplete Migration

`lib/features/` contains only barrel re-export files pointing back to `coach/` and `assistant/`:

Text ```
lib/features/index.dart
lib/features/conflict_resolution/index.dart
lib/features/race_management/index.dart
lib/features/results/index.dart
lib/features/runner_management/index.dart
lib/features/timing/index.dart


This is the skeleton of an architectural migration that was never completed. The files add indirection with no structural value and can be confusing to new contributors.

### Auth Guard in SyncService Commented Out

The sign-in check before sync operations in [sync_service.dart](core/services/sync_service.dart) is commented out. Sync can run for unauthenticated users; protection is handled piecemeal per-row. The intent and safe behavior are unclear from reading the code.

### Mock/Dev Screen in Production Build

`mock_data_test_screen.dart` (a developer testing screen) is exported from `shared/screens/main_screens.dart` and is present in production builds.

### Commented-Out Test Suite

Tests were written and appear to have been functional at some point, but were commented out — almost certainly during a model/API refactor that was never reconciled. See the Testing section below.

---

## Test Coverage

Test coverage of business logic is near-zero. Of roughly 18 test files, the majority contain only commented-out code or a placeholder assertion.

### Active Tests (confirmed running)

| File | What It Tests |
|---|---|
| `test/integration/wireless_connection_test.dart` | P2P data transfer and rescan logic (Mockito, ~270 lines) |
| `test/unit/coach/timing_data_converter_test.dart` | `UIChunk.insertTimeAt` for missing-time conflict resolution (5 tests) |
| `test/unit/race_share_test.dart` | Race share encode/decode payload (3 tests) |

### Commented Out or Placeholder (not running)

| File | Nominal Subject |
|---|---|
| `test/unit/assistant/race_timer/controller/timing_controller_test.dart` | `TimingController` |
| `test/unit/assistant/race_timer/model/timing_data_test.dart` | `TimingData` model |
| `test/unit/coach/merge_conflicts_controller_test.dart` | `MergeConflictsController` |
| `test/unit/coach/race_results/controller/race_results_controller_test.dart` | `RaceResultsController` |
| `test/unit/utils/encode_utils_test.dart` | Encode utilities |
| `test/unit/coach/encode_utils_test.dart` | Coach encode utilities |
| `test/widget/coach/race_results/widgets/collapsible_results_widget_test.dart` | Widget (placeholder only: `expect(true, isTrue)`) |
| (several others) | Merge conflicts service, assistant encoding, device manager |

### Completely Untested (no file exists)

- `TimingController` business logic
- `BibNumberController` / `BibNumberDataController`
- `RaceController` / `RacesController`
- `DatabaseHelper` (all CRUD)
- `MasterRace` singleton and cache behavior
- `SyncService` (push/pull, conflict resolution)
- `AuthService`
- All screens and widgets (except placeholder)
- All geolocation utilities

---

## 5 Biggest Architectural Risks

### 1. Controllers Storing `BuildContext` — Active Crash Risk

`TimingController`, `RacesController`, `MergeConflictsController`, and `BibNumberController` all store a raw `BuildContext` reference and dereference it (`_context!`) in 15+ places without checking `.mounted` first. When a screen unmounts while an async operation is in flight, this produces use-after-free crashes.

Flutter's recommendation is to never store `BuildContext` in a `ChangeNotifier`. The safe pattern is to pass context at the call site or use a callback/navigator key approach.

**Files affected:**

- [lib/coach/race_screen/controller/race_screen_controller.dart](coach/race_screen/controller/race_screen_controller.dart)
- [lib/assistant/race_timer/controller/timing_controller.dart](assistant/race_timer/controller/timing_controller.dart)
- [lib/coach/races_screen/controller/races_controller.dart](coach/races_screen/controller/races_controller.dart)
- [lib/coach/merge_conflicts/controller/merge_conflicts_controller.dart](coach/merge_conflicts/controller/merge_conflicts_controller.dart)
- [lib/assistant/bib_number_recorder/controller/bib_number_controller.dart](assistant/bib_number_recorder/controller/bib_number_controller.dart)

---

### 2. God Classes — Maintenance and Correctness Drag

Several classes are far too large and mix too many responsibilities. This makes bugs hard to isolate and changes high-risk.

- **`RaceController`** (948 lines): owns 6 `TextEditingController`s, form validation state, change tracking (`originalValues`, `changedFields`), loading flags, flow state, geolocation, dialog orchestration, navigation, device connection creation, and data loading.
- **`BibNumberController`** (1,180 lines, two classes in one file): includes a method (`showRunnersLoadedSheet`) that constructs a full `Column`/`Row`/`ListView.builder` widget tree inside the controller — zero separation of concerns.
- **`DatabaseHelper`** (882 lines): a monolithic repository covering runners, teams, races, participants, results, and sync utilities all in one class with no domain boundaries.

A parallel 5-way `switch` on string field names (`'name'`, `'location'`, `'date'`, `'distance'`) appears in 5 separate methods of `RaceController`. Adding a new field requires updating all 5 switch blocks.

---

### 3. Near-Zero Test Coverage on All Business Logic

The three active test files cover only encode/decode and one conflict-resolution method. Every controller, every service, every model, and every widget is untested. The commented-out tests suggest this coverage once existed and was lost — meaning there's a documented prior regression that hasn't been recovered.

Any refactor of `TimingController`, `DatabaseHelper`, `SyncService`, or `MasterRace` is being done without a safety net.

---

### 4. Dual Database / Dual Model Duplication Between Roles

The Coach role and Assistant role maintain entirely separate SQLite databases with separate models:

- `lib/shared/models/database/runner.dart` vs `lib/assistant/shared/models/runner.dart`
- `lib/shared/models/database/race.dart` vs `lib/assistant/shared/models/race_record.dart`
- `lib/assistant/bib_number_recorder/model/bib_record.dart` vs `lib/assistant/shared/models/bib_record.dart`

Two `TimingDataConverter` classes with the same name exist in different subtrees with similar but divergent `UIChunk` types that are never shared. This duplication makes it easy to fix a bug in one place and miss the parallel location, and makes the data flow harder to reason about.

---

### 5. MasterRace Global Singleton Accumulates Deleted Instances

`MasterRace._instances` is a static `Map<int, MasterRace>` that is populated when races are loaded but never cleared when races are deleted. `deleteRace` in `RacesController` does not call `MasterRace.clearInstance(raceId)`. On a device used heavily over time (e.g., a coach who creates and deletes many races per season), this will grow without bound.

Additionally, `clearInstance` throws a `StateError` if called with an unknown key, making defensive cleanup calls unsafe without a guard check — which means the code that should clean up will instead throw.

---

*Assessment performed by automated codebase analysis. Verify specific line numbers against the current branch before acting on them.*
