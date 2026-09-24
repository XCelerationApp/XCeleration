import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/race_results/model/results_record.dart';

// Results go to spectators as text and are read back on their phone, so a
// finish time has to come back exactly as it left.

void main() {
  ResultsRecord record(Duration finish) => ResultsRecord(
        place: 1,
        name: 'Alice',
        team: 'Eagles',
        teamAbbreviation: 'EAG',
        grade: 10,
        bib: '101',
        raceId: 1,
        runnerId: 1,
        finishTime: finish,
      );

  for (final finish in const [
    Duration(minutes: 16, seconds: 3, milliseconds: 780),
    Duration(minutes: 9, seconds: 59, milliseconds: 990),
    Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 450),
    Duration(hours: 2),
  ]) {
    test('$finish comes back unchanged', () {
      final back = ResultsRecord.fromMap(record(finish).toMap());

      expect(back.finishTime, finish);
    });
  }
}
