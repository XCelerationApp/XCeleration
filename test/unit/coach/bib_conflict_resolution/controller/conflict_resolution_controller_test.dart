import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/controller/conflict_resolution_controller.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
import 'package:xceleration/coach/bib_conflict_resolution/services/runner_creator.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Resolving a race's bib conflicts. What matters in the end is who finished
// at each place, so every test checks the places, not just the screens.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

RaceRunner _runner(int id, String bib, String name) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: id, name: name, bibNumber: bib, grade: 10),
      team: _eagles,
    );

final _quinn = _runner(1, '959', 'Quinn');
final _gray = _runner(2, '949', 'Gray');
final _nico = _runner(3, '956', 'Nico');
final _sage = _runner(4, '961', 'Sage');

/// Bib 959 recorded at 16th and 21st.
final _duplicate = DuplicateBibConflict(
  bibNumber: '959',
  runner: _quinn,
  occurrences: const [
    ConflictOccurrence(place: 16, time: '15:50.00'),
    ConflictOccurrence(place: 21, time: '16:03.78'),
  ],
);

/// Bib 959 recorded at 5th, 16th and 21st.
final _triplicate = DuplicateBibConflict(
  bibNumber: '959',
  runner: _quinn,
  occurrences: const [
    ConflictOccurrence(place: 5),
    ConflictOccurrence(place: 16),
    ConflictOccurrence(place: 21),
  ],
);

/// Bib 9567 at 17th, which nobody has.
const _unknown = UnknownBibConflict(
  bibNumber: '9567',
  occurrence: ConflictOccurrence(place: 17, time: '15:52.10'),
);

void main() {
  late List<NewRunner> saved;
  Result<RaceRunner> Function(NewRunner)? saveResult;

  setUp(() {
    saved = [];
    saveResult = null;
  });

  ConflictResolutionController make({
    List<BibConflict>? conflicts,
    List<RaceRunner>? candidates,
    Map<String, String> savedBibOwners = const {},
  }) =>
      ConflictResolutionController(
        conflicts: conflicts ?? [_duplicate, _unknown],
        candidates: candidates ?? [_gray, _nico, _sage],
        knownBibs: {'959', '949', '956', '961'},
        savedBibOwners: savedBibOwners,
        teams: const ['Eagles', 'Owls'],
        raceName: 'Invitational',
        createRunner: (newRunner) async {
          saved.add(newRunner);
          return saveResult?.call(newRunner) ??
              Success(RaceRunner(
                raceId: 1,
                runner: Runner(
                  runnerId: 99,
                  name: newRunner.name,
                  bibNumber: newRunner.bibNumber,
                  grade: newRunner.grade,
                ),
                team: _eagles,
              ));
        },
      );

  group('choosing the order', () {
    test('starts on the summary', () {
      final c = make();
      expect(c.isOnSummary, isTrue);
      expect(c.resolvedCount, 0);
      expect(c.totalConflicts, 2);
    });

    test('starting opens the first conflict', () {
      final c = make()..startResolving();
      expect(c.isOnConflict, isTrue);
      expect(c.currentConflict, same(_duplicate));
    });

    test('any conflict can be opened first', () {
      final c = make()..openConflict(1);
      expect(c.currentConflict, same(_unknown));
    });

    test('finishing the last conflict goes back for one left open earlier',
        () async {
      final c = make()..openConflict(1);
      c.prepareAssign(_nico, 'Bib #9567');
      await c.commitPending();

      expect(c.isOnConflict, isTrue);
      expect(c.currentConflict, same(_duplicate),
          reason: 'the duplicate was skipped, not resolved');
    });
  });

  group('an unrecognised bib', () {
    test('gives its finish to the runner picked', () async {
      final c = make()..openConflict(1);

      c.prepareAssign(_nico, 'Bib #9567');
      expect(c.hasPending, isTrue);
      expect(c.resolvedByPlace, isEmpty, reason: 'nothing settles until the toast runs out');
      await c.commitPending();

      expect(c.resolvedByPlace, {17: _nico});
      expect(c.isResolved(1), isTrue);
    });

    test('undo puts the runner back in the list', () {
      final c = make()..openConflict(1);
      c.prepareAssign(_nico, 'Bib #9567');
      expect(c.runnersNearBib('9567'), isNot(contains(_nico)));

      c.undoPending();

      expect(c.resolvedByPlace, isEmpty);
      expect(c.runnersNearBib('9567'), contains(_nico));
    });
  });

  group('a repeated bib', () {
    test('keeps the runner at the finish the coach chose', () {
      final c = make()..startResolving();

      c.chooseDuplicateOccurrence(16);

      expect(c.resolvedByPlace[16], _quinn);
      expect(c.currentLeftover?.place, 21);
      expect(c.isResolved(0), isFalse, reason: '21st still has nobody');
    });

    test('the other finish is whoever the coach assigns', () async {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(16);

      c.prepareAssignForDuplicate(_gray, '21st place (Bib #959)');
      await c.commitPending();

      expect(c.resolvedByPlace, {16: _quinn, 21: _gray});
      expect(c.isResolved(0), isTrue);
      expect(c.currentConflict, same(_unknown), reason: 'on to the next open one');
    });

    test('the choice can go either way', () async {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(21);
      c.prepareAssignForDuplicate(_gray, '16th place (Bib #959)');
      await c.commitPending();

      expect(c.resolvedByPlace, {21: _quinn, 16: _gray});
    });

    test('three finishes are worked through one at a time', () async {
      final c = make(conflicts: [_triplicate])..startResolving();
      c.chooseDuplicateOccurrence(16);
      expect(c.leftoversRemaining, 2);
      expect(c.currentLeftover?.place, 5);

      c.prepareAssignForDuplicate(_gray, '5th');
      await c.commitPending();
      expect(c.isOnConflict, isTrue, reason: 'still one finish to go');
      expect(c.currentLeftover?.place, 21);

      c.prepareAssignForDuplicate(_nico, '21st');
      await c.commitPending();

      expect(c.resolvedByPlace, {5: _gray, 16: _quinn, 21: _nico});
      expect(c.isOnCompletion, isTrue);
    });

    test('back after choosing asks again rather than leaving', () {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(16);

      c.goBack();

      expect(c.isOnConflict, isTrue);
      expect(c.chosenPlace, isNull);
      expect(c.resolvedByPlace, isEmpty,
          reason: 'the kept finish goes with the choice');
    });

    test('ignores a place the bib was not recorded at', () {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(3);
      expect(c.chosenPlace, isNull);
    });
  });

  group('adding a runner', () {
    test('saves them only once the toast runs out', () async {
      final c = make()..openConflict(1);

      c.prepareCreate('Avery Stone', '9567', 'Eagles', 11, 'Bib #9567');
      expect(saved, isEmpty,
          reason: 'an undone creation must not leave a runner in the race');
      await c.commitPending();

      expect(saved.single.name, 'Avery Stone');
      expect(c.resolvedByPlace[17]!.runner.runnerId, 99);
      expect(c.resolutionLog.single.kind, ResolutionKind.created);
    });

    test('undo never saves them', () {
      final c = make()..openConflict(1);
      c.prepareCreate('Avery Stone', '9567', 'Eagles', 11, 'Bib #9567');

      c.undoPending();

      expect(saved, isEmpty);
    });

    test('a failed save leaves the finish open and says why', () async {
      saveResult = (_) => const Failure(AppError(userMessage: 'Could not save.'));
      final c = make()..openConflict(1);
      c.prepareCreate('Avery Stone', '9567', 'Eagles', 11, 'Bib #9567');

      await c.commitPending();

      expect(c.resolvedByPlace, isEmpty);
      expect(c.error?.userMessage, 'Could not save.');
      expect(c.hasPending, isFalse, reason: 'so the coach can try again');
    });

    test('their bib counts as taken from then on', () async {
      final c = make()..openConflict(1);
      c.prepareCreate('Avery Stone', '977', 'Eagles', 11, 'Bib #9567');
      expect(c.allKnownBibs, contains('977'));
      await c.commitPending();
      expect(c.allKnownBibs, contains('977'));
    });

    test('a new bib is free here and among runners saved elsewhere', () {
      expect(make().nextFreeBib, '962');
      expect(make(savedBibOwners: {'962': 'Sam Lee'}).nextFreeBib, '963');
    });

    test('a leftover finish can go to someone new', () async {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(16);

      c.prepareCreateForDuplicate('Avery Stone', '977', 'Eagles', 11, '21st');
      await c.commitPending();

      expect(c.resolvedByPlace[21]!.runner.name, 'Avery Stone');
      expect(c.resolvedByPlace[16], _quinn);
    });
  });

  group('the runner list', () {
    test('puts the nearest bib numbers first', () {
      final c = make()..openConflict(1);
      // 957 is nearest to 956 (Nico), then 961, then 949.
      expect(c.runnersNearBib('957').map((r) => r.runner.bibNumber),
          ['956', '961', '949']);
    });

    test('leaves out runners already given a finish', () async {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(16);
      c.prepareAssignForDuplicate(_gray, '21st');
      await c.commitPending();

      expect(c.runnersNearBib('9567'), isNot(contains(_gray)));
    });
  });

  group('the review', () {
    Future<ConflictResolutionController> finished() async {
      final c = make()..startResolving();
      c.chooseDuplicateOccurrence(16);
      c.prepareAssignForDuplicate(_gray, '21st');
      await c.commitPending();
      c.prepareAssign(_nico, 'Bib #9567');
      await c.commitPending();
      return c;
    }

    test('comes once every conflict is settled', () async {
      final c = await finished();
      expect(c.isOnCompletion, isTrue);
      expect(c.resolvedCount, 2);
    });

    test('lists every finish in finish order, the kept one included',
        () async {
      final c = await finished();
      expect(c.resolutionLog.map((e) => e.place), [16, 17, 21]);
      expect(c.resolutionLog.map((e) => e.kind), [
        ResolutionKind.kept,
        ResolutionKind.assigned,
        ResolutionKind.assigned,
      ]);
    });

    test('back goes to the summary with everything still settled', () async {
      final c = await finished();
      c.goBack();
      expect(c.isOnSummary, isTrue);
      expect(c.resolvedByPlace, hasLength(3));
    });

    test('reopening a conflict clears it to be done again', () async {
      final c = await finished();
      c.goBack();

      c.openConflict(0);

      expect(c.resolvedByPlace.keys, [17], reason: 'only the other conflict stays');
      expect(c.runnersNearBib('9567'), contains(_gray),
          reason: 'Gray is free again');
    });
  });
}
