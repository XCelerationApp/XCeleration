import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/model/bib_conflict.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Working out what is actually wrong with the bibs the recorder handed over.
//
// The finish order arrives as a list: a runner where the bib matched someone,
// and the bare bib number where it did not. Two things can be wrong with it —
// a bib recorded at more than one finish, and a bib nobody has.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

RaceRunner _runner(int id, String bib, {String? name}) => RaceRunner(
      raceId: 1,
      runner: Runner(
          runnerId: id, name: name ?? 'Runner $id', bibNumber: bib, grade: 10),
      team: _eagles,
    );

Future<RaceRunner?> Function(String) _lookup(Map<String, RaceRunner> known) =>
    (bib) async => known[bib];

void main() {
  group('a bib recorded at more than one finish', () {
    test('asks about every place it was recorded, not just the later ones',
        () async {
      // Bib 12 was recorded 2nd and 4th. Neither is automatically the right
      // one — that is the question being put to the coach.
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [_runner(2, '11'), alice, _runner(3, '13'), alice],
        timesByPlace: const {
          1: '15:00.00',
          2: '15:02.00',
          3: '15:04.00',
          4: '15:06.00',
        },
        lookupBib: _lookup({'12': alice}),
      );

      expect(conflicts, hasLength(1));
      final duplicate = conflicts.single as DuplicateBibConflict;
      expect(duplicate.bibNumber, '12');
      expect(duplicate.runner.runner.name, 'Alice');
      expect(duplicate.occurrences.map((o) => o.place), [2, 4]);
      expect(duplicate.occurrences.map((o) => o.time),
          ['15:02.00', '15:06.00']);
    });

    test('handles a bib recorded three times', () async {
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [alice, _runner(2, '11'), alice, alice],
        timesByPlace: const {},
        lookupBib: _lookup({'12': alice}),
      );

      final duplicate = conflicts.single as DuplicateBibConflict;
      expect(duplicate.occurrences.map((o) => o.place), [1, 3, 4]);
    });

    test('pairs an unresolved entry with the runner that holds the bib',
        () async {
      // The second recording of bib 12 never got matched to a runner, so it
      // arrives as bare text; it is still the same duplicate.
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [alice, '12'],
        timesByPlace: const {},
        lookupBib: _lookup({'12': alice}),
      );

      final duplicate = conflicts.single as DuplicateBibConflict;
      expect(duplicate.occurrences.map((o) => o.place), [1, 2]);
    });

    test('leaves the time out where the Timer has not settled that place',
        () async {
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [alice, alice],
        timesByPlace: const {1: '15:00.00'},
        lookupBib: _lookup({'12': alice}),
      );

      final duplicate = conflicts.single as DuplicateBibConflict;
      expect(duplicate.occurrences.map((o) => o.time), ['15:00.00', null]);
    });
  });

  group('a bib nobody has', () {
    test('is reported with the place it was recorded at', () async {
      final conflicts = await detectBibConflicts(
        entries: [_runner(1, '11'), '99'],
        timesByPlace: const {1: '15:00.00', 2: '15:02.00'},
        lookupBib: _lookup({}),
      );

      final unknown = conflicts.single as UnknownBibConflict;
      expect(unknown.bibNumber, '99');
      expect(unknown.occurrence.place, 2);
      expect(unknown.occurrence.time, '15:02.00');
    });

    test('is separate from a duplicate of the same bib text', () async {
      // Bib 99 belongs to nobody and was recorded twice: two unknowns, not a
      // duplicate, because there is no runner to duplicate.
      final conflicts = await detectBibConflicts(
        entries: ['99', '99'],
        timesByPlace: const {},
        lookupBib: _lookup({}),
      );

      expect(conflicts, hasLength(2));
      expect(conflicts.every((c) => c is UnknownBibConflict), isTrue);
    });
  });

  group('the rest of the field', () {
    test('a clean finish order has nothing wrong with it', () async {
      final conflicts = await detectBibConflicts(
        entries: [_runner(1, '11'), _runner(2, '12')],
        timesByPlace: const {},
        lookupBib: _lookup({}),
      );

      expect(conflicts, isEmpty);
    });

    test('reports conflicts in finish order', () async {
      final alice = _runner(1, '12');
      final conflicts = await detectBibConflicts(
        entries: ['99', _runner(2, '11'), alice, alice],
        timesByPlace: const {},
        lookupBib: _lookup({'12': alice}),
      );

      expect(conflicts.first, isA<UnknownBibConflict>());
      expect(conflicts.last, isA<DuplicateBibConflict>());
    });

    test('gives each conflict the finishers either side of it', () async {
      final conflicts = await detectBibConflicts(
        entries: [
          _runner(1, '11', name: 'Ahead'),
          '99',
          _runner(2, '13', name: 'Behind'),
        ],
        timesByPlace: const {1: '15:00.00', 2: '15:02.00', 3: '15:04.00'},
        lookupBib: _lookup({}),
      );

      final unknown = conflicts.single as UnknownBibConflict;
      expect(unknown.nearby.map((f) => f.name), ['Ahead', 'Behind']);
      expect(unknown.nearby.map((f) => f.place), [1, 3]);
      expect(unknown.nearby.first.time, '15:00.00');
      expect(unknown.nearby.first.bibNumber, '11');
    });

    test('leaves other conflicts out of the nearby finishers', () async {
      // A runner whose own bib is in question is no help in placing someone.
      final conflicts = await detectBibConflicts(
        entries: ['98', '99', _runner(1, '13', name: 'Known')],
        timesByPlace: const {},
        lookupBib: _lookup({}),
      );

      final first = conflicts.first as UnknownBibConflict;
      expect(first.nearby.map((f) => f.name), ['Known']);
    });
  });
}
