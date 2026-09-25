import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// Undoing an add or a remove in a conflict batch, before "Resolve Conflict"
// is pressed. Each test checks the times the screen would save, not just the
// button state: an undo that leaves the right buttons but the wrong times is
// worse than no undo at all.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _team = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int n) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: n, name: 'Runner $n', bibNumber: '$n', grade: 11),
      team: _team,
    );

List<RaceRunner> _runners(int n) => List.generate(n, (i) => _runner(i + 1));

String _t(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.00';

TimingChunk _chunk(int id, List<int> seconds, ConflictType type,
        {int offBy = 1, required int end}) =>
    TimingChunk(
      id: id,
      timingData: seconds.map((s) => TimingDatum(time: _t(s))).toList(),
      conflictRecord: TimingDatum(
        time: _t(end),
        conflict: Conflict(type: type, offBy: offBy),
      ),
    );

MergeConflictsController _controller(
        List<TimingChunk> chunks, List<RaceRunner> runners) =>
    MergeConflictsController(
      masterRace: MasterRace.getInstance(1),
      timingChunks: chunks,
      raceRunners: runners,
      scheduler: _NoopScheduler(),
    );

UIChunk _ui(MergeConflictsController c, int chunkId) =>
    c.uiChunks.firstWhere((u) => u.chunkId == chunkId);

List<String> _times(MergeConflictsController c, int chunkId) =>
    _ui(c, chunkId).records.map((r) => r.time).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(MasterRace.clearAllInstances);

  group('undoing a removed extra time', () {
    test('nothing to undo before anything is touched', () {
      final c = _controller(
        [_chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13)],
        _runners(2),
      );

      expect(c.canUndo(0), isFalse);
      expect(c.undoLabel(0), isNull);
    });

    test('puts the time back where it was', () {
      final c = _controller(
        [_chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13)],
        _runners(2),
      );

      c.removeExtraTimeRecord(0, 1);
      expect(_times(c, 0), [_t(10), _t(12)]);
      expect(c.canUndo(0), isTrue);

      c.undo(0);

      expect(_times(c, 0), [_t(10), _t(11), _t(12)]);
      expect(_ui(c, 0).conflict.offBy, 1,
          reason: 'the batch is one time over again');
      expect(_ui(c, 0).records[2].runner, isNull,
          reason: 'the last time is extra again');
      expect(c.canUndo(0), isFalse, reason: 'nothing left to undo');
    });

    test('says which time it will put back', () {
      final c = _controller(
        [_chunk(0, [10, 11, 12], ConflictType.extraTime, end: 13)],
        _runners(2),
      );

      c.removeExtraTimeRecord(0, 1);

      expect(c.undoLabel(0), contains(_t(11)));
    });

    test('steps back through several removals one at a time', () {
      final c = _controller(
        [_chunk(0, [10, 11, 12, 13], ConflictType.extraTime, offBy: 2, end: 14)],
        _runners(2),
      );

      c.removeExtraTimeRecord(0, 1);
      c.removeExtraTimeRecord(0, 1);
      expect(_times(c, 0), [_t(10), _t(13)]);

      c.undo(0);
      expect(_times(c, 0), [_t(10), _t(12), _t(13)]);

      c.undo(0);
      expect(_times(c, 0), [_t(10), _t(11), _t(12), _t(13)]);
      expect(c.canUndo(0), isFalse);
    });

    test('turns "Resolve Conflict" back off', () {
      final c = _controller(
        [_chunk(0, [10, 11], ConflictType.extraTime, end: 12)],
        _runners(1),
      );

      c.removeExtraTimeRecord(0, 1);
      expect(_ui(c, 0).isResolvedLocally, isTrue);

      c.undo(0);

      expect(_ui(c, 0).isResolvedLocally, isFalse,
          reason: 'the conflict is unresolved again');
    });
  });

  group('undoing a placed missing time', () {
    test('puts the TBD back where it was', () {
      // Two runners, one time: the coach must say who is missing.
      final c = _controller(
        [_chunk(0, [10], ConflictType.missingTime, end: 12)],
        _runners(2),
      );
      expect(_times(c, 0), [_t(10), 'TBD']);

      // The missed runner came in first, not second.
      c.insertTbdAt(0, 0);
      expect(_times(c, 0), ['TBD', _t(10)]);
      expect(c.canUndo(0), isTrue);

      c.undo(0);

      expect(_times(c, 0), [_t(10), 'TBD']);
      expect(c.canUndo(0), isFalse);
    });

    test('keeps a time typed before the TBD was moved', () {
      // One recorded time and two runners the Timer missed.
      final c = _controller(
        [_chunk(0, [10], ConflictType.missingTime, offBy: 2, end: 14)],
        _runners(3),
      );

      c.updateMissingTimeRecord(0, 2, _t(13));
      expect(_times(c, 0), [_t(10), 'TBD', _t(13)]);

      c.insertTbdAt(0, 0);
      expect(_times(c, 0), ['TBD', _t(10), _t(13)]);

      c.undo(0);

      expect(_times(c, 0), [_t(10), 'TBD', _t(13)],
          reason: 'undo puts the slot back without losing what was typed');
    });

    test('a typed time is not itself undone', () {
      // Typing is its own correction — the coach can retype. Undo is for the
      // + and X buttons, which move other rows around.
      final c = _controller(
        [_chunk(0, [10], ConflictType.missingTime, end: 14)],
        _runners(2),
      );

      c.updateMissingTimeRecord(0, 1, _t(12));

      expect(c.canUndo(0), isFalse);
    });
  });

  group('what undo does not reach', () {
    test('resolving the batch clears its history', () async {
      final c = _controller(
        [_chunk(0, [10, 11], ConflictType.extraTime, end: 12)],
        _runners(1),
      );

      c.removeExtraTimeRecord(0, 1);
      expect(c.canUndo(0), isTrue);

      await c.resolveExtraTimeConflict(0);

      expect(c.canUndo(0), isFalse,
          reason: 'the coach committed the batch on purpose');
    });

    test('each batch keeps its own history', () {
      final c = _controller(
        [
          _chunk(0, [10, 11], ConflictType.extraTime, end: 12),
          _chunk(1, [20, 21], ConflictType.extraTime, end: 22),
        ],
        _runners(2),
      );

      c.removeExtraTimeRecord(0, 1);
      c.removeExtraTimeRecord(1, 1);

      c.undo(0);

      expect(_times(c, 0), [_t(10), _t(11)]);
      expect(_times(c, 1), [_t(20)], reason: 'the other batch is untouched');
      expect(c.canUndo(1), isTrue);
    });

    test('undoing an unknown batch does nothing', () {
      final c = _controller(
        [_chunk(0, [10, 11], ConflictType.extraTime, end: 12)],
        _runners(1),
      );

      c.undo(99);

      expect(_times(c, 0), [_t(10), _t(11)]);
    });
  });
}
