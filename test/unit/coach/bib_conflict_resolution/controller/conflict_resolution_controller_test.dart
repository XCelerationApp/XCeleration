import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/controller/conflict_resolution_controller.dart';
import 'package:xceleration/coach/bib_conflict_resolution/mock/conflict_mock_data.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// ---------------------------------------------------------------------------
// Minimal test fixtures — independent of ConflictMockData
// ---------------------------------------------------------------------------

final _teamA = Team(name: 'Team A');
final _teamB = Team(name: 'Team B');

final _runnerA = RaceRunner(
  raceId: 1,
  runner: Runner(bibNumber: '10', name: 'Alice', grade: 11),
  team: _teamA,
);
final _runnerB = RaceRunner(
  raceId: 1,
  runner: Runner(bibNumber: '20', name: 'Bob', grade: 12),
  team: _teamB,
);

final _duplicateConflict = MockDuplicateConflict(
  raceRunner: RaceRunner(
    raceId: 1,
    runner: Runner(bibNumber: '10', name: 'Alice', grade: 11),
    team: _teamA,
  ),
  occurrences: const [
    (position: 1, formattedTime: '15:00'),
    (position: 3, formattedTime: '15:30'),
  ],
  surroundingFinishers: const [],
);

final _tripleConflict = MockDuplicateConflict(
  raceRunner: RaceRunner(
    raceId: 1,
    runner: Runner(bibNumber: '20', name: 'Bob', grade: 12),
    team: _teamB,
  ),
  occurrences: const [
    (position: 2, formattedTime: '15:10'),
    (position: 4, formattedTime: '15:40'),
    (position: 6, formattedTime: '16:00'),
  ],
  surroundingFinishers: const [],
);

const _unknownConflict = MockUnknownConflict(
  enteredBib: 99,
  position: 5,
  formattedTime: '15:50',
  surroundingFinishers: [],
);

ConflictResolutionController _makeController({
  List<MockBibConflict>? conflicts,
  List<RaceRunner>? runners,
}) {
  final controller = ConflictResolutionController(
    conflicts: conflicts ?? [_duplicateConflict],
    unassignedRunners: runners ?? [_runnerA, _runnerB],
  );
  controller.startResolving();
  return controller;
}

// ---------------------------------------------------------------------------

void main() {
  group('ConflictResolutionController', () {
    // --- startResolving ---

    group('startResolving', () {
      test('sets step to duplicateStep1 when first conflict is duplicate', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        expect(controller.isOnDuplicateStep1, isTrue);
      });

      test('sets step to unknown when first conflict is unknown', () {
        final controller = _makeController(conflicts: [_unknownConflict]);
        expect(controller.isOnUnknown, isTrue);
      });

      test('resets resolvedCount to 0', () {
        final controller = _makeController();
        expect(controller.resolvedCount, 0);
      });

      test('resets conflict index to 0', () {
        final controller = _makeController();
        expect(controller.currentConflictIndex, 0);
      });

      test('clears any pending state', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.startResolving();
        expect(controller.hasPending, isFalse);
      });

      test('resets unassigned runners to initial list', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        controller.startResolving();
        expect(controller.runnersNearBib(10).length, 2);
      });
    });

    // --- teams getter ---

    group('teams', () {
      test('returns sorted unique team names from initial runners', () {
        final controller = _makeController(runners: [_runnerA, _runnerB]);
        expect(controller.teams, ['Team A', 'Team B']);
      });

      test('deduplicates team names', () {
        final dup = RaceRunner(
          raceId: 1,
          runner: Runner(bibNumber: '30', name: 'Carol', grade: 10),
          team: _teamA,
        );
        final controller = _makeController(runners: [_runnerA, dup]);
        expect(controller.teams, ['Team A']);
      });
    });

    // --- runnersNearBib ---

    group('runnersNearBib', () {
      test('returns runners sorted by proximity to target bib', () {
        final controller = _makeController();
        final runners = controller.runnersNearBib(12);
        expect(int.parse(runners.first.runner.bibNumber ?? '0'), 10); // |10-12|=2, |20-12|=8
      });

      test('returns empty list when no unassigned runners remain', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'label');
        controller.prepareAssign(_runnerB, 'label');
        expect(controller.runnersNearBib(10), isEmpty);
      });
    });

    // --- allKnownBibs ---

    group('allKnownBibs', () {
      test('includes conflict bib numbers', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        expect(controller.allKnownBibs, contains(10));
      });

      test('includes unassigned runner bib numbers', () {
        final controller = _makeController();
        expect(controller.allKnownBibs, containsAll([10, 20]));
      });

      test('includes unknown conflict entered bib', () {
        final controller = _makeController(conflicts: [_unknownConflict]);
        expect(controller.allKnownBibs, contains(99));
      });
    });

    // --- prepareAssign ---

    group('prepareAssign', () {
      test('sets hasPending to true', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        expect(controller.hasPending, isTrue);
      });

      test('sets pendingLabel', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        expect(controller.pendingLabel, 'Bib #10');
      });

      test('removes the runner from the unassigned list immediately', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        expect(
          controller.runnersNearBib(10).any(
            (r) => int.parse(r.runner.bibNumber ?? '0') == 10,
          ),
          isFalse,
        );
      });
    });

    // --- prepareCreate ---

    group('prepareCreate', () {
      test('sets hasPending to true', () {
        final controller = _makeController();
        controller.prepareCreate('New Guy', 99, 'Team A', 11, 'Bib #99');
        expect(controller.hasPending, isTrue);
      });

      test('does not modify unassigned runners list', () {
        final controller = _makeController();
        final before = controller.runnersNearBib(10).length;
        controller.prepareCreate('New Guy', 99, 'Team A', 11, 'Bib #99');
        expect(controller.runnersNearBib(10).length, before);
      });
    });

    // --- commitPending ---

    group('commitPending', () {
      test('clears hasPending', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.hasPending, isFalse);
      });

      test('advances to next conflict after commit', () {
        final controller = _makeController(
          conflicts: [_duplicateConflict, _unknownConflict],
        );
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.currentConflictIndex, 1);
      });

      test('appends assign entry to resolutionLog', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.resolutionLog.length, 1);
        expect(controller.resolutionLog.first.wasCreate, isFalse);
        expect(controller.resolutionLog.first.runnerName, 'Alice');
      });

      test('appends create entry to resolutionLog', () {
        final controller = _makeController();
        controller.prepareCreate('New Guy', 99, 'Team A', 11, 'Bib #99');
        controller.commitPending();
        expect(controller.resolutionLog.first.wasCreate, isTrue);
        expect(controller.resolutionLog.first.runnerName, 'New Guy');
      });

      test('resolvedRunners contains a RaceRunner for each committed resolution', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.resolvedRunners.length, 1);
        expect(controller.resolvedRunners.first.runner.name, 'Alice');
      });

      test('resolvedRunners includes RaceRunner for created runner', () {
        final controller = _makeController();
        controller.prepareCreate('New Guy', 99, 'Team A', 11, 'Bib #99');
        controller.commitPending();
        expect(controller.resolvedRunners.length, 1);
        expect(controller.resolvedRunners.first.runner.bibNumber, '99');
        expect(controller.resolvedRunners.first.runner.name, 'New Guy');
      });

      test('transitions to completion after last conflict', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.isOnCompletion, isTrue);
      });

      test('does nothing when no pending resolution', () {
        final controller = _makeController();
        controller.commitPending(); // no-op
        expect(controller.resolvedCount, 0);
      });

      test('increments runnersAssigned on assign commit', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.commitPending();
        expect(controller.runnersAssigned, 1);
      });

      test('increments newRunnersCreated on create commit', () {
        final controller = _makeController();
        controller.prepareCreate('New Guy', 99, 'Team A', 11, 'Bib #99');
        controller.commitPending();
        expect(controller.newRunnersCreated, 1);
      });
    });

    // --- undoPending ---

    group('undoPending', () {
      test('clears hasPending', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.undoPending();
        expect(controller.hasPending, isFalse);
      });

      test('restores runner to unassigned list after assign undo', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.undoPending();
        expect(
          controller.runnersNearBib(10).any(
            (r) => int.parse(r.runner.bibNumber ?? '0') == 10,
          ),
          isTrue,
        );
      });

      test('does not change conflict index', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.undoPending();
        expect(controller.currentConflictIndex, 0);
      });

      test('does nothing when no pending resolution', () {
        final controller = _makeController();
        controller.undoPending(); // no-op
        expect(controller.hasPending, isFalse);
      });
    });

    // --- goBack ---

    group('goBack', () {
      test('undoes pending resolution when pending is set', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'Bib #10');
        controller.goBack();
        expect(controller.hasPending, isFalse);
      });

      test('steps back one conflict and removes log entry', () {
        final controller = _makeController(
          conflicts: [_duplicateConflict, _unknownConflict],
        );
        controller.prepareAssign(_runnerA, 'label');
        controller.commitPending();
        expect(controller.currentConflictIndex, 1);

        controller.goBack();
        expect(controller.currentConflictIndex, 0);
        expect(controller.resolutionLog, isEmpty);
      });

      test('returns from completion to last conflict', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.prepareAssign(_runnerA, 'label');
        controller.commitPending();
        expect(controller.isOnCompletion, isTrue);

        controller.goBack();
        expect(controller.isOnCompletion, isFalse);
        expect(controller.isOnDuplicateStep1, isTrue);
      });

      test('does nothing when at first conflict with no pending', () {
        final controller = _makeController();
        controller.goBack();
        expect(controller.currentConflictIndex, 0);
      });
    });

    // --- chooseDuplicateOccurrence ---

    group('chooseDuplicateOccurrence', () {
      test('injects leftover occurrences as unknown conflicts', () {
        final controller = _makeController(
          conflicts: [_duplicateConflict, _unknownConflict],
        );
        // _duplicateConflict has positions 1 and 3 — confirm position 1
        controller.chooseDuplicateOccurrence(1);
        // leftover (position 3) should be injected at index 1
        expect(controller.totalConflicts, 3); // original 2 + 1 injected
      });

      test('increments duplicatesResolved', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.chooseDuplicateOccurrence(1);
        expect(controller.duplicatesResolved, 1);
      });

      test('advances to the injected unknown conflict', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.chooseDuplicateOccurrence(1);
        expect(controller.isOnUnknown, isTrue);
      });

      test('injects N-1 unknowns for N-occurrence duplicate', () {
        final controller = _makeController(
          conflicts: [_tripleConflict],
        );
        // _tripleConflict has 3 occurrences — confirm one, expect 2 injected
        controller.chooseDuplicateOccurrence(2);
        expect(controller.totalConflicts, 3); // original 1 + 2 injected
      });
    });

    // --- prepareAssignForDuplicate / prepareCreateForDuplicate ---

    group('prepareAssignForDuplicate', () {
      test('increments both duplicatesResolved and runnersAssigned on commit', () {
        final controller = _makeController();
        controller.prepareAssignForDuplicate(_runnerA, 'label');
        controller.commitPending();
        expect(controller.duplicatesResolved, 1);
        expect(controller.runnersAssigned, 1);
      });
    });

    group('prepareCreateForDuplicate', () {
      test('increments both duplicatesResolved and newRunnersCreated on commit', () {
        final controller = _makeController();
        controller.prepareCreateForDuplicate('New', 99, 'Team A', 11, 'label');
        controller.commitPending();
        expect(controller.duplicatesResolved, 1);
        expect(controller.newRunnersCreated, 1);
      });
    });

    // --- resolvedCount ---

    group('resolvedCount', () {
      test('returns 0 at start', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        expect(controller.resolvedCount, 0);
      });

      test('returns index+1 while a resolution is pending', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'label');
        expect(controller.resolvedCount, 1);
      });

      test('returns total on completion', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.prepareAssign(_runnerA, 'label');
        controller.commitPending();
        expect(controller.resolvedCount, 1);
        expect(controller.totalConflicts, 1);
      });
    });

    // --- canGoBack ---

    group('canGoBack', () {
      test('false at the start with no pending', () {
        final controller = _makeController();
        expect(controller.canGoBack, isFalse);
      });

      test('true when a resolution is pending', () {
        final controller = _makeController();
        controller.prepareAssign(_runnerA, 'label');
        expect(controller.canGoBack, isTrue);
      });

      test('true when past the first conflict', () {
        final controller = _makeController(
          conflicts: [_duplicateConflict, _unknownConflict],
        );
        controller.prepareAssign(_runnerA, 'label');
        controller.commitPending();
        expect(controller.canGoBack, isTrue);
      });

      test('true when on completion screen', () {
        final controller = _makeController(conflicts: [_duplicateConflict]);
        controller.prepareAssign(_runnerA, 'label');
        controller.commitPending();
        expect(controller.isOnCompletion, isTrue);
        expect(controller.canGoBack, isTrue);
      });
    });
  });
}
