import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

RaceRunner _runner(int id) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: id, name: 'Runner $id', bibNumber: '$id', grade: 11),
      team: const Team(teamId: 1, name: 'Eagles'),
    );

TimingChunk _chunk(int id, List<String> times, [Conflict? conflict, String end = '20:00.0']) =>
    TimingChunk(
      id: id,
      timingData: [for (final t in times) TimingDatum(time: t)],
      conflictRecord: conflict == null ? null : TimingDatum(time: end, conflict: conflict),
    );

void main() {
  final runners = [for (var i = 1; i <= 6; i++) _runner(i)];

  test('a hidden chunk still takes its places and runners', () {
    final ui = CoachTimingDataConverter.convertToUIChunks([
      _chunk(0, ['10:00.0', '10:01.0']), // no conflict: not shown
      _chunk(1, ['10:02.0', '10:03.0'], Conflict(type: ConflictType.confirmRunner)),
    ], runners);

    expect(ui.single.startingPlace, 3);
    expect([for (final r in ui.single.records) r.runner?.runner.runnerId], [3, 4]);
  });

  test('shows a missing-time chunk that has no recorded times', () {
    // The Timer creates this when "missing time" is pressed right after a
    // confirmation; hiding it left a conflict nobody could resolve.
    final ui = CoachTimingDataConverter.convertToUIChunks([
      _chunk(0, ['10:00.0'], Conflict(type: ConflictType.confirmRunner)),
      _chunk(1, [], Conflict(type: ConflictType.missingTime, offBy: 2)),
    ], runners);

    expect(ui, hasLength(2));
    expect([for (final r in ui.last.records) r.time], ['TBD', 'TBD']);
    expect([for (final r in ui.last.records) r.runner?.runner.runnerId], [2, 3]);
  });

  test('every slot in a missing-time chunk gets its runner', () {
    final ui = CoachTimingDataConverter.convertToUIChunks([
      _chunk(0, ['10:00.0', '10:01.0'], Conflict(type: ConflictType.missingTime, offBy: 2)),
    ], runners);

    expect([for (final r in ui.single.records) r.runner?.runner.runnerId], [1, 2, 3, 4]);
    expect([for (final r in ui.single.records) r.place], [1, 2, 3, 4]);
  });

  test('does not crash when there are fewer runners than times', () {
    final ui = CoachTimingDataConverter.convertToUIChunks([
      _chunk(0, ['10:00.0', '10:01.0'], Conflict(type: ConflictType.confirmRunner)),
    ], [_runner(1)]);

    expect(ui.single.records.last.runner, isNull);
  });
}
