import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/shared/services/received_race_resolver.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

// How the coach's new roster differs from the one on the phone, told to the
// volunteer when the race is sent again.

void main() {
  BibDatum runner(String bib, String name, {String team = 'NHS'}) =>
      BibDatum(bib: bib, name: name, teamAbbreviation: team, grade: '10');

  group('RosterChanges', () {
    final before = [runner('1', 'Ava'), runner('2', 'Mia'), runner('3', 'Zoe')];

    test('counts runners added, removed and changed', () {
      final changes = RosterChanges.between(before, [
        runner('1', 'Ava'),
        runner('2', 'Mia', team: 'RHS'),
        runner('4', 'Lily'),
        runner('5', 'Nora'),
      ]);

      expect(changes.added, 2);
      expect(changes.removed, 1);
      expect(changes.changed, 1);
      expect(changes.describe(), '4 runners: 2 added, 1 removed, 1 changed');
    });

    test('says nothing when the roster is the same', () {
      final changes = RosterChanges.between(before, [...before]);

      expect(changes.isEmpty, isTrue);
      expect(changes.describe(), isNull);
    });

    test('speaks of one runner in the singular', () {
      expect(
        RosterChanges.between(before, [
          ...before,
          runner('4', 'Lily'),
        ]).describe(),
        '1 runner: 1 added',
      );
    });
  });
}
