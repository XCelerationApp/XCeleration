import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// How many finishers a batch of times accounts for, while the coach is part
// way through a missing time. An open slot used to count twice (as a "TBD"
// time and in the missing count), so resolving the last batch turned it into
// "an extra time" that was not there.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _team = Team(teamId: 1, name: 'Eagles');

List<RaceRunner> _runners(int n) => [
      for (var i = 1; i <= n; i++)
        RaceRunner(
          raceId: 1,
          runner:
              Runner(runnerId: i, name: 'Runner $i', bibNumber: '$i', grade: 11),
          team: _team,
        ),
    ];

String _t(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.00';

TimingChunk _missing(int id, List<int> seconds, {required int end}) =>
    TimingChunk(
      id: id,
      timingData: seconds.map((s) => TimingDatum(time: _t(s))).toList(),
      conflictRecord: TimingDatum(
        time: _t(end),
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      ),
    );

MergeConflictsController _controller(List<TimingChunk> chunks, int runners) =>
    MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: chunks,
      raceRunners: _runners(runners),
      scheduler: _NoopScheduler(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MasterRace.clearAllInstances);

  group('a batch missing a time counts each finisher once', () {
    test('as the Timer sent it', () {
      expect(_missing(0, [10, 20], end: 30).recordCount, 3);
    });

    test('with the open slot written into its times', () {
      final chunk = TimingChunk(
        id: 0,
        timingData: [for (final t in ['TBD', _t(10), _t(20)]) TimingDatum(time: t)],
        conflictRecord: TimingDatum(
          time: _t(30),
          conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
        ),
      );
      expect(chunk.recordCount, 3);
    });
  });

  test('placing a slot without typing leaves the other batches alone',
      () async {
    final c = _controller([
      _missing(0, [10, 20], end: 30),
      _missing(1, [40, 50], end: 60),
    ], 6);

    // The coach moves the first batch's slot but doesn't know the time yet.
    c.insertTbdAt(0, 0);
    expect(c.timingChunks.map((ch) => ch.recordCount), [3, 3]);
    expect(c.uiChunks[1].records.first.place, 4,
        reason: 'the second batch still starts at 4th place');

    // Then finishes the last batch.
    final slot = c.uiChunks[1].records.indexWhere((r) => r.isUnfilled);
    c.updateMissingTimeRecord(1, slot, '0:55.00');
    await c.resolveMissingTimeConflict(1);

    final last = c.timingChunks.last;
    expect(last.conflictRecord!.conflict!.type, ConflictType.confirmRunner,
        reason: 'no extra time appears in the batch just resolved');
    expect(last.timingData.map((d) => d.time), [_t(40), _t(50), '0:55.00']);
  });
}
