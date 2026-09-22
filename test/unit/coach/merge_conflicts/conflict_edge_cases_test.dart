import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// Edge cases for resolving timing conflicts on the coach, including the
// scenarios from the old (since deleted) MergeConflictsService tests, ported
// to the current chunk model. Every test ends by checking what would be saved:
// one readable, ascending time per runner, in finish order.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  int calls = 0;
  @override
  void addPostFrameCallback(VoidCallback callback) => calls++;
}

const _team = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int n) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: n, name: 'Runner $n', bibNumber: '$n', grade: 11),
      team: _team,
    );

List<RaceRunner> _runners(int n) => List.generate(n, (i) => _runner(i + 1));

/// A time [seconds] after the start, e.g. 75 -> '1:15.00'.
String _t(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.00';

TimingChunk _chunk(int id, List<int> seconds, ConflictType type,
    {int offBy = 1, required int end}) {
  return TimingChunk(
    id: id,
    timingData: seconds.map((s) => TimingDatum(time: _t(s))).toList(),
    conflictRecord: TimingDatum(
      time: _t(end),
      conflict: Conflict(type: type, offBy: offBy),
    ),
  );
}

MergeConflictsController _controller(
    List<TimingChunk> chunks, List<RaceRunner> runners) {
  return MergeConflictsController(
    masterRace: MasterRace.getInstance(1),
    timingChunks: chunks,
    raceRunners: runners,
    scheduler: _NoopScheduler(),
  );
}

UIChunk _ui(MergeConflictsController c, int chunkId) =>
    c.uiChunks.firstWhere((u) => u.chunkId == chunkId);

/// What LoadResultsController would save: every chunk's times in order.
List<String> _savedTimes(MergeConflictsController c) =>
    c.timingChunks.expand((ch) => ch.timingData.map((d) => d.time)).toList();

/// Asserts the result is saveable: one readable time per runner, ascending.
void _expectSaveable(MergeConflictsController c, int runnerCount) {
  expect(c.hasConflicts, isFalse, reason: 'conflicts remain');
  final times = _savedTimes(c);
  expect(times.length, runnerCount, reason: 'one time per runner');
  Duration? previous;
  for (final time in times) {
    final d = TimeFormatter.loadDurationFromString(time);
    expect(d, isNotNull, reason: '"$time" is not a time');
    if (previous != null) {
      expect(d! > previous, isTrue, reason: 'times out of order at $time');
    }
    previous = d;
  }
}

/// Types [value] into a missing-time slot without pressing Enter.
void _type(MergeConflictsController c, int chunkId, int index, String value) =>
    c.updateMissingTimeRecord(chunkId, index, value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MasterRace.clearAllInstances);

  group('extra times', () {
    test('removing the real extra time realigns the runners after it',
        () async {
      // Runner 1 at 10s, a stray time at 11s, runner 2 at 12s.
      final c = _controller(
        [_chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13)],
        _runners(2),
      );

      // Before removal the stray time sits on runner 2 and 12s is "extra".
      expect(_ui(c, 0).records[1].runner!.runner.runnerId, 2);
      expect(_ui(c, 0).records[2].runner, isNull);

      c.removeExtraTimeRecord(0, 1);

      final ui = _ui(c, 0);
      expect(ui.times, [_t(10), _t(12)]);
      expect(ui.records[1].runner!.runner.runnerId, 2);
      expect(ui.isResolvedLocally, isTrue);

      await c.resolveExtraTimeConflict(0);
      _expectSaveable(c, 2);
      expect(_savedTimes(c), [_t(10), _t(12)]);
    });

    test('cannot remove more times than the conflict says are extra', () {
      final c = _controller(
        [_chunk(0, [10, 11, 12, 13], ConflictType.extraTime, offBy: 2, end: 14)],
        _runners(2),
      );

      c.removeExtraTimeRecord(0, 0);
      c.removeExtraTimeRecord(0, 0);
      expect(c.timingChunks.single.conflictRecord!.conflict!.offBy, 0);

      // A third removal would take a runner's time.
      expect(c.removeExtraTime(0, 0), isFalse);
      c.removeExtraTimeRecord(0, 0);
      expect(_savedTimes(c), [_t(12), _t(13)]);
    });

    test('resolving is refused while extra times remain', () async {
      final c = _controller(
        [_chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13)],
        _runners(2),
      );

      await c.resolveExtraTimeConflict(0);

      expect(c.timingChunks.single.conflictRecord!.conflict!.type,
          ConflictType.extraTime);
      expect(c.hasConflicts, isTrue);
    });
  });

  group('missing times', () {
    test('a time typed without pressing Enter is saved on resolve', () async {
      final c = _controller(
        [_chunk(0, [10, 14], ConflictType.missingTime, end: 15)],
        _runners(3),
      );
      // TBD slot is last; move it between 10s and 14s, then type 12s.
      c.insertTbdAt(0, 1);
      expect(_ui(c, 0).times, [_t(10), 'TBD', _t(14)]);
      _type(c, 0, 1, _t(12));
      expect(_ui(c, 0).isResolvedLocally, isTrue);

      await c.resolveMissingTimeConflict(0);

      _expectSaveable(c, 3);
      expect(_savedTimes(c), [_t(10), _t(12), _t(14)]);
    });

    test('resolving is refused while a slot is still empty', () async {
      final c = _controller(
        [_chunk(0, [10], ConflictType.missingTime, offBy: 2, end: 15)],
        _runners(3),
      );
      _type(c, 0, 1, _t(12));

      await c.resolveMissingTimeConflict(0);

      expect(c.hasConflicts, isTrue);
      expect(_savedTimes(c), [_t(10)]);
      expect(_ui(c, 0).records[2].validationError, isNotNull);
    });

    test('a chunk with no recorded times (missing right after a confirm)',
        () async {
      final c = _controller([
        _chunk(0, [10, 11], ConflictType.confirmRunner, end: 12),
        _chunk(1, [], ConflictType.missingTime, end: 20),
      ], _runners(3));
      c.initState();

      final ui = _ui(c, 1);
      expect(ui.times, ['TBD']);
      expect(ui.records.single.runner!.runner.runnerId, 3);
      _type(c, 1, 0, _t(15));

      await c.resolveMissingTimeConflict(1);

      _expectSaveable(c, 3);
      expect(_savedTimes(c), [_t(10), _t(11), _t(15)]);
    });

    test('an entered time must come after earlier chunks\' finishers', () {
      final c = _controller([
        _chunk(0, [10, 20], ConflictType.confirmRunner, end: 21),
        _chunk(1, [30], ConflictType.missingTime, end: 40),
      ], _runners(4));
      c.insertTbdAt(1, 0); // missed finisher came in before 30s

      _type(c, 1, 0, _t(19));
      expect(_ui(c, 1).records[0].validationError, isNotNull);

      _type(c, 1, 0, _t(25));
      expect(_ui(c, 1).records[0].validationError, isNull);
    });

    test('an entered time outside its neighbours is rejected', () {
      final c = _controller(
        [_chunk(0, [10, 14], ConflictType.missingTime, end: 15)],
        _runners(3),
      );
      c.insertTbdAt(0, 1);

      _type(c, 0, 1, _t(16)); // after 14s, but the slot is before it
      expect(_ui(c, 0).records[1].validationError, isNotNull);
      _type(c, 0, 1, _t(10)); // equal to the runner before
      expect(_ui(c, 0).records[1].validationError, isNotNull);
    });

    test('an entered time stays editable after it is saved', () async {
      final c = _controller(
        [_chunk(0, [10, 20], ConflictType.missingTime, offBy: 2, end: 30)],
        _runners(4),
      );
      // Fill the first slot and submit; one slot is still missing.
      _type(c, 0, 2, _t(25));
      await c.submitMissingTimeRecord(0, 2, _t(25));
      c.invalidateUICache();

      final ui = _ui(c, 0);
      expect(ui.records[2].time, _t(25));
      expect(ui.records[2].isOriginallyTBD, isTrue,
          reason: 'the coach must still be able to fix a typo');
      expect(ui.records[0].isOriginallyTBD, isFalse);
    });
  });

  test('entered times stay editable when the sheet is closed and reopened',
      () async {
    final chunks = [
      _chunk(0, [10, 20], ConflictType.missingTime, offBy: 2, end: 30),
    ];
    final recorded = MergeConflictsController.recordedTimesOf(chunks);
    final first = MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: chunks,
      raceRunners: _runners(4),
      scheduler: _NoopScheduler(),
      recordedTimes: recorded,
    );
    _type(first, 0, 2, _t(25));
    await first.submitMissingTimeRecord(0, 2, _t(25));

    // Reopened: a new controller on the same (partly entered) chunks.
    final reopened = MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: chunks,
      raceRunners: _runners(4),
      scheduler: _NoopScheduler(),
      recordedTimes: recorded,
    );

    final ui = _ui(reopened, 0);
    expect(ui.records[2].time, _t(25));
    expect(ui.records[2].isOriginallyTBD, isTrue);
    expect(ui.records[0].isOriginallyTBD, isFalse);
  });

  test('an extra time and an unnoticed missed runner in the last chunk',
      () async {
    // 4 real finishers; the Timer tapped a stray (11s) and marked it, but
    // also missed the runner at 14s without noticing.
    final c = _controller([
      _chunk(0, [10, 11, 12, 16], ConflictType.extraTime, end: 17),
    ], _runners(4));

    c.removeExtraTimeRecord(0, 1);
    await c.resolveExtraTimeConflict(0);

    // Not confirmed: one finisher is still missing.
    final conflict = c.timingChunks.single.conflictRecord!.conflict!;
    expect(conflict.type, ConflictType.missingTime);
    expect(conflict.offBy, 1);

    c.insertTbdAt(0, 2); // before 16s
    _type(c, 0, 2, _t(14));
    await c.resolveMissingTimeConflict(0);

    _expectSaveable(c, 4);
    expect(_savedTimes(c), [_t(10), _t(12), _t(14), _t(16)]);
  });

  test('a missing time and an unnoticed stray tap in the last chunk',
      () async {
    // 3 real finishers; the Timer missed one (and marked it) but also
    // recorded a stray at 13s without noticing.
    final c = _controller([
      _chunk(0, [10, 13, 15], ConflictType.missingTime, end: 17),
    ], _runners(3));

    c.insertTbdAt(0, 1); // the missed runner came in before 13s
    _type(c, 0, 1, _t(11));
    await c.resolveMissingTimeConflict(0);

    final conflict = c.timingChunks.single.conflictRecord!.conflict!;
    expect(conflict.type, ConflictType.extraTime);
    expect(conflict.offBy, 1);

    c.removeExtraTimeRecord(0, 2); // 13s
    await c.resolveExtraTimeConflict(0);

    _expectSaveable(c, 3);
    expect(_savedTimes(c), [_t(10), _t(11), _t(15)]);
  });

  group('placing TBD slots', () {
    test('two slots can be placed independently', () {
      final c = _controller(
        [_chunk(0, [10, 20, 30], ConflictType.missingTime, offBy: 2, end: 40)],
        _runners(5),
      );
      expect(_ui(c, 0).times, [_t(10), _t(20), _t(30), 'TBD', 'TBD']);

      c.insertTbdAt(0, 1); // before 20s
      expect(_ui(c, 0).times, [_t(10), 'TBD', _t(20), _t(30), 'TBD']);

      c.insertTbdAt(0, 3); // before 30s; the first slot stays put
      expect(_ui(c, 0).times, [_t(10), 'TBD', _t(20), 'TBD', _t(30)]);
    });

    test('moving a slot from before the target lands directly before it', () {
      final c = _controller(
        [_chunk(0, [10, 20, 30], ConflictType.missingTime, end: 40)],
        _runners(4),
      );
      c.insertTbdAt(0, 0);
      expect(_ui(c, 0).times, ['TBD', _t(10), _t(20), _t(30)]);

      c.insertTbdAt(0, 3); // before 30s
      expect(_ui(c, 0).times, [_t(10), _t(20), 'TBD', _t(30)]);
    });

    test('runners and places stay in finish order when a slot moves', () {
      final c = _controller(
        [_chunk(0, [10, 20, 30], ConflictType.missingTime, end: 40)],
        _runners(4),
      );

      c.insertTbdAt(0, 1);

      final records = _ui(c, 0).records;
      expect(records.map((r) => r.runner!.runner.runnerId), [1, 2, 3, 4]);
      expect(records.map((r) => r.place), [1, 2, 3, 4]);
      expect(records[1].isOriginallyTBD, isTrue);
      expect(records[3].isOriginallyTBD, isFalse);
    });

    test('an entered time moves with its slot and is checked again', () {
      final c = _controller(
        [_chunk(0, [10, 20, 30], ConflictType.missingTime, offBy: 2, end: 40)],
        _runners(5),
      );
      _type(c, 0, 3, _t(35)); // valid in the last-but-one slot
      expect(_ui(c, 0).records[3].validationError, isNull);

      // The nearest empty slot after index 0 is the last one; moving it
      // shifts the entered 35s along, where it is still valid.
      c.insertTbdAt(0, 0);
      final ui = _ui(c, 0);
      expect(ui.times, ['TBD', _t(10), _t(20), _t(30), _t(35)]);
      expect(ui.records[4].validationError, isNull);
      expect(ui.records[4].isOriginallyTBD, isTrue);
    });
  });

  test('a full race with every kind of conflict (old service scenario)',
      () async {
    // Places: 1-5 confirmed, 6-9 one missing, 10-11 confirmed,
    // 12-13 one extra, 14-17 one missing, 18-21 confirmed.
    final c = _controller([
      _chunk(0, [60, 61, 62, 63, 64], ConflictType.confirmRunner, end: 65),
      _chunk(1, [70, 71, 73], ConflictType.missingTime, end: 75),
      _chunk(2, [80, 81], ConflictType.confirmRunner, end: 82),
      _chunk(3, [90, 91, 92], ConflictType.extraTime, end: 93),
      _chunk(4, [100, 101, 103], ConflictType.missingTime, end: 105),
      _chunk(5, [110, 111, 112, 113], ConflictType.confirmRunner, end: 114),
    ], _runners(21));
    c.initState();

    // Each conflict chunk starts at the right place and runner.
    expect(_ui(c, 1).startingPlace, 6);
    expect(_ui(c, 1).records.first.runner!.runner.runnerId, 6);
    expect(_ui(c, 3).startingPlace, 12);
    expect(_ui(c, 3).records.first.runner!.runner.runnerId, 12);
    expect(_ui(c, 4).startingPlace, 14);
    expect(_ui(c, 4).records.first.runner!.runner.runnerId, 14);

    // Missing time between 71s and 73s.
    c.insertTbdAt(1, 2);
    _type(c, 1, 2, _t(72));
    await c.resolveMissingTimeConflict(1);

    // 91s was a stray tap.
    c.removeExtraTimeRecord(3, 1);
    await c.resolveExtraTimeConflict(3);

    // Missing time between 101s and 103s.
    c.insertTbdAt(4, 2);
    _type(c, 4, 2, _t(102));
    await c.resolveMissingTimeConflict(4);

    _expectSaveable(c, 21);
    expect(_savedTimes(c), [
      _t(60), _t(61), _t(62), _t(63), _t(64), //
      _t(70), _t(71), _t(72), _t(73), //
      _t(80), _t(81), //
      _t(90), _t(92), //
      _t(100), _t(101), _t(102), _t(103), //
      _t(110), _t(111), _t(112), _t(113),
    ]);
  });

  test('resolving conflicts in any order gives the same result', () async {
    List<TimingChunk> chunks() => [
          _chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13),
          _chunk(1, [20], ConflictType.missingTime, end: 25),
          _chunk(2, [30, 31], ConflictType.confirmRunner, end: 32),
        ];

    // 2 + 2 + 2 finishers.
    final forward = _controller(chunks(), _runners(6));
    forward.initState();
    forward.removeExtraTimeRecord(0, 2);
    await forward.resolveExtraTimeConflict(0);
    _type(forward, 1, 1, _t(22));
    await forward.resolveMissingTimeConflict(1);

    MasterRace.clearAllInstances();
    final backward = _controller(chunks(), _runners(6));
    backward.initState();
    _type(backward, 1, 1, _t(22));
    await backward.resolveMissingTimeConflict(1);
    backward.removeExtraTimeRecord(0, 2);
    await backward.resolveExtraTimeConflict(0);

    _expectSaveable(forward, 6);
    expect(_savedTimes(backward), _savedTimes(forward));
  });
}
