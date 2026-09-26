import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/model/bib_conflict.dart';
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

    test('gives each finish its own neighbours', () async {
      // Choosing between two finishes means knowing who each sits between.
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [
          _runner(2, '11', name: 'First'),
          alice,
          _runner(3, '13', name: 'Third'),
          alice,
          _runner(4, '14', name: 'Fifth'),
        ],
        timesByPlace: const {},
        lookupBib: _lookup({'12': alice}),
      );

      final duplicate = conflicts.single as DuplicateBibConflict;
      // Each finish's own neighbourhood, skipping the other disputed place.
      expect(duplicate.occurrences[0].nearby.map((f) => f.name),
          ['First', 'Third', 'Fifth']);
      expect(duplicate.occurrences[1].nearby.map((f) => f.name),
          ['First', 'Third', 'Fifth']);
      expect(duplicate.occurrences[0].nearby.map((f) => f.place), [1, 3, 5]);
    });

    test('carries up to four finishers either side for "See more"', () async {
      final alice = _runner(1, '12', name: 'Alice');
      final field = [
        for (var i = 0; i < 12; i++) _runner(100 + i, '${200 + i}'),
      ];
      // Alice recorded 7th and 8th in a field of 14.
      final entries = [...field.take(6), alice, alice, ...field.skip(6)];
      final conflicts = await detectBibConflicts(
        entries: entries,
        timesByPlace: const {},
        lookupBib: _lookup({'12': alice}),
      );

      final first = (conflicts.single as DuplicateBibConflict).occurrences[0];
      // Four ahead of 7th (3–6), four behind it (9–12), skipping disputed 8th.
      expect(first.nearby.map((f) => f.place), [3, 4, 5, 6, 9, 10, 11, 12]);
      // "Show all finishers": the whole field, less the disputed places.
      expect(first.allFinishers.map((f) => f.place),
          [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14]);
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

  group('a finish whose time is not settled yet', () {
    // Not "time unknown": the coach sees where it must fall, between the
    // known times on either side.
    test('shows the range between the known times either side', () async {
      final alice = _runner(1, '12', name: 'Alice');
      final conflicts = await detectBibConflicts(
        entries: [_runner(2, '10'), alice, _runner(3, '11'), alice, _runner(4, '13')],
        timesByPlace: const {1: '15:00.00', 3: '15:05.00', 5: '15:09.00'},
        lookupBib: _lookup({'12': alice}),
      );

      final places = (conflicts.single as DuplicateBibConflict).occurrences;
      expect(places.map((o) => o.timeLabel), [
        'Between 15:00.00 and 15:05.00',
        'Between 15:05.00 and 15:09.00',
      ]);
    });

    test('says only after or before at either end, or nothing', () {
      expect(const ConflictOccurrence(place: 9, after: '15:00.00').timeLabel,
          'After 15:00.00');
      expect(const ConflictOccurrence(place: 1, before: '15:00.00').timeLabel,
          'Before 15:00.00');
      expect(const ConflictOccurrence(place: 1).timeLabel, isNull);
      expect(
          const ConflictOccurrence(place: 1, time: '15:01.00', after: 'x')
              .timeLabel,
          '15:01.00');
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
      expect(unknown.occurrence.nearby.map((f) => f.name), ['Ahead', 'Behind']);
      expect(unknown.occurrence.nearby.map((f) => f.place), [1, 3]);
      expect(unknown.occurrence.nearby.first.time, '15:00.00');
      expect(unknown.occurrence.nearby.first.bibNumber, '11');
    });

    test('leaves other conflicts out of the nearby finishers', () async {
      // A runner whose own bib is in question is no help in placing someone.
      final conflicts = await detectBibConflicts(
        entries: ['98', '99', _runner(1, '13', name: 'Known')],
        timesByPlace: const {},
        lookupBib: _lookup({}),
      );

      final first = conflicts.first as UnknownBibConflict;
      expect(first.occurrence.nearby.map((f) => f.name), ['Known']);
    });
  });
}
