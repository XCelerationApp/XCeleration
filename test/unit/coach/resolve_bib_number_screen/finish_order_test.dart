import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/model/finish_order.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Writing a resolution back into the finish order.
//
// The rest of the post-race flow reads this list by position: place is index
// plus one, and every time assignment follows from it. Putting the right
// runner at the wrong place would give somebody else's time to a runner and
// look perfectly correct on screen.

const _eagles = Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG');

RaceRunner _runner(int id, String bib) => RaceRunner(
      raceId: 1,
      runner:
          Runner(runnerId: id, name: 'Runner $id', bibNumber: bib, grade: 10),
      team: _eagles,
    );

List<String> _bibs(List<dynamic> entries) => [
      for (final entry in entries)
        entry is RaceRunner ? (entry.runner.bibNumber ?? '?') : '<$entry>',
    ];

void main() {
  group('assigning runners to finishes', () {
    test('puts each runner at the place they finished', () {
      final entries = [_runner(1, '11'), '99', _runner(2, '13')];

      final result = applyResolvedFinishes(entries, {2: _runner(3, '12')});

      expect(_bibs(result), ['11', '12', '13']);
    });

    test('settles both finishes of a repeated bib at once', () {
      // Bib 12 was recorded 2nd and 4th; 2nd is its owner, 4th was a typo.
      final alice = _runner(1, '12');
      final entries = [_runner(2, '11'), alice, _runner(3, '13'), alice];

      final result = applyResolvedFinishes(entries, {
        2: alice,
        4: _runner(4, '14'),
      });

      expect(_bibs(result), ['11', '12', '13', '14']);
    });

    test('leaves every other finish exactly where it was', () {
      final entries = [_runner(1, '11'), '99', _runner(2, '13')];

      final result = applyResolvedFinishes(entries, {2: _runner(3, '12')});

      expect(result.first, same(entries.first));
      expect(result.last, same(entries.last));
    });

    test('does not change the list it was given', () {
      final entries = [_runner(1, '11'), '99'];

      applyResolvedFinishes(entries, {2: _runner(3, '12')});

      expect(entries[1], '99');
    });

    test('ignores a place that is not in the race', () {
      final entries = [_runner(1, '11')];

      final result = applyResolvedFinishes(entries, {
        0: _runner(2, '12'),
        5: _runner(3, '13'),
      });

      expect(_bibs(result), ['11']);
    });
  });

  group('removing a finish', () {
    test('moves everyone after it up one place', () {
      final entries = [_runner(1, '11'), '99', _runner(2, '13')];

      final result = removeFinish(entries, 2);

      expect(_bibs(result), ['11', '13']);
    });

    test('leaves the finishes before it alone', () {
      final entries = [_runner(1, '11'), _runner(2, '12'), '99'];

      final result = removeFinish(entries, 3);

      expect(_bibs(result), ['11', '12']);
    });

    test('ignores a place that is not in the race', () {
      final entries = [_runner(1, '11')];

      expect(_bibs(removeFinish(entries, 0)), ['11']);
      expect(_bibs(removeFinish(entries, 2)), ['11']);
    });
  });
}
