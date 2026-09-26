import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/runners_management_screen/services/roster_update.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// Updating a team from a newer copy of its roster spreadsheet: who is new,
// whose details changed, and who is no longer listed, before anything changes.

Runner _r(int id, String name, String bib, int grade) =>
    Runner(runnerId: id, name: name, bibNumber: bib, grade: grade);

Map<String, dynamic> _row(String name, String bib, int grade,
        {String? team, String? gender}) =>
    {
      'name': name,
      'bib': bib,
      'grade': grade,
      'team': ?team,
      'gender': ?gender,
    };

void main() {
  group('planRosterUpdate', () {
    final ann = _r(1, 'Ann Lee', '101', 10);
    final bo = _r(2, 'Bo Park', '102', 11);
    final cy = _r(3, 'Cy Diaz', '103', 12);

    test('finds new runners, changed details, and runners no longer listed',
        () {
      final plan = planRosterUpdate(current: [ann, bo, cy], rows: [
        _row('Ann Lee', '101', 10), // the same
        _row('Bo Park', '102', 12), // grade changed
        _row('Di Fox', '104', 9), // new
      ]);

      expect(plan.added.map((r) => r['name']), ['Di Fox']);
      expect(plan.changed.single.before, bo);
      expect(plan.changed.single.after.grade, 12);
      expect(plan.removed, [cy]);
    });

    test('a runner given a new bib is a change, not a swap', () {
      final plan = planRosterUpdate(
          current: [ann], rows: [_row('ann lee', '201', 10)]);

      expect(plan.added, isEmpty);
      expect(plan.removed, isEmpty);
      expect(plan.changed.single.after.bibNumber, '201');
    });

    test('a renamed runner keeps their bib', () {
      final plan = planRosterUpdate(
          current: [ann], rows: [_row('Annie Lee', '101', 10)]);

      expect(plan.changed.single.after.name, 'Annie Lee');
      expect(plan.changed.single.after.runnerId, ann.runnerId);
    });

    test('nothing to do when the sheet matches the team', () {
      final plan = planRosterUpdate(
          current: [ann, bo],
          rows: [_row('Ann Lee', '101', 10), _row('Bo Park', '102', 11)]);

      expect(plan.isEmpty, isTrue);
    });
  });

  group('rowsForTeam', () {
    const archie = Team(teamId: 1, name: 'Archie Williams', abbreviation: 'AW');
    const archieBoys =
        Team(teamId: 2, name: 'Archie Williams - Boys', abbreviation: 'AWB');

    final rows = [
      _row('Ann', '1', 10, team: 'Archie Williams', gender: 'F'),
      _row('Bo', '2', 10, team: 'Archie Williams', gender: 'M'),
      _row('Cy', '3', 10, team: 'Drake', gender: 'M'),
    ];

    test('keeps the rows naming the team', () {
      expect(rowsForTeam(rows, archie).map((r) => r['name']), ['Ann', 'Bo']);
    });

    test('a boys\' team takes its school\'s boys', () {
      expect(rowsForTeam(rows, archieBoys).map((r) => r['name']), ['Bo']);
    });

    test('a sheet without a Team column is all this team\'s', () {
      final plain = [_row('Ann', '1', 10), _row('Bo', '2', 10)];
      expect(rowsForTeam(plain, archie), hasLength(2));
    });
  });
}
