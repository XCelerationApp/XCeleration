import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/database/race.dart';

// Every race row on the phone is read through Race.fromJson to build the
// races list, so one row it cannot read must not take the list down.

void main() {
  Map<String, dynamic> row(Map<String, dynamic> overrides) => {
        'race_id': 1,
        'name': 'Invitational',
        'race_date': '2026-09-12T00:00:00.000',
        'distance': 3.1,
        'flow_state': Race.FLOW_SETUP,
        ...overrides,
      };

  test('reads a race row', () {
    final race = Race.fromJson(row({}));

    expect(race.raceName, 'Invitational');
    expect(race.raceDate, DateTime(2026, 9, 12));
    expect(race.distance, 3.1);
  });

  test('an empty race date, the column default, is no date', () {
    expect(Race.fromJson(row({'race_date': ''})).raceDate, isNull);
  });

  test('an unreadable timestamp is left out rather than thrown', () {
    final race = Race.fromJson(row({'updated_at': 'not a time'}));

    expect(race.updatedAt, isNull);
    expect(race.raceName, 'Invitational');
  });

  test('reads a timestamp written by SQLite', () {
    final race = Race.fromJson(row({'created_at': '2026-09-12 08:30:00'}));

    expect(race.createdAt, DateTime(2026, 9, 12, 8, 30));
  });
}
