import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/utils/race_to_reopen.dart';

RaceRecord _race(int id, DateTime date,
        {DateTime? startedAt, bool stopped = true, String? name}) =>
    RaceRecord(
      raceId: id,
      date: date,
      name: name ?? 'Race $id',
      type: 'timer',
      startedAt: startedAt,
      stopped: stopped,
    );

void main() {
  final demo = _race(-1, DateTime(2026, 9, 1), name: 'Demo Race');
  final older = _race(1, DateTime(2026, 9, 5));
  final newer = _race(2, DateTime(2026, 9, 20));

  test('nothing to open', () => expect(raceToReopen([]), isNull));

  test('a running race wins, even with an older date', () {
    final running = _race(3, DateTime(2026, 9, 1),
        startedAt: DateTime(2026, 9, 21, 10), stopped: false);
    // Listed newest date first, as storage returns them.
    expect(raceToReopen([newer, older, running, demo]), running);
  });

  test('otherwise the most recently started race', () {
    final a = _race(3, DateTime(2026, 9, 20), startedAt: DateTime(2026, 9, 20));
    final b = _race(4, DateTime(2026, 9, 10), startedAt: DateTime(2026, 9, 21));
    expect(raceToReopen([a, b, demo]), b);
  });

  test('otherwise the real race with the newest date, not the demo', () {
    expect(raceToReopen([newer, older, demo]), newer);
  });

  test('the demo race when it is the only one', () {
    expect(raceToReopen([demo]), demo);
  });
}
