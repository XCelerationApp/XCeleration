import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/utils/settled_times.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// Which finish places have a time that is already settled.
//
// Bib conflicts are resolved before timing conflicts, so when the coach is
// asked which finish belongs to a runner, some of the Timer's times may still
// be in dispute. A place inside a chunk the Timer flagged has no time yet —
// showing one would be a guess — but every other place does, including the
// places after the flagged stretch, because the chunk still accounts for a
// known number of finishers.

String _t(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.00';

TimingChunk _chunk(
  int id,
  List<int> seconds, {
  ConflictType type = ConflictType.confirmRunner,
  int offBy = 0,
  List<String>? rawTimes,
}) =>
    TimingChunk(
      id: id,
      timingData: (rawTimes ?? seconds.map(_t).toList())
          .map((t) => TimingDatum(time: t))
          .toList(),
      conflictRecord: TimingDatum(
        time: _t(seconds.isEmpty ? 0 : seconds.last + 1),
        conflict: Conflict(type: type, offBy: offBy),
      ),
    );

void main() {
  test('gives every place a time when the Timer flagged nothing', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11, 12]),
    ]);

    expect(times, {1: _t(10), 2: _t(11), 3: _t(12)});
  });

  test('carries on across several clean chunks', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11]),
      _chunk(1, [12, 13]),
    ]);

    expect(times, {1: _t(10), 2: _t(11), 3: _t(12), 4: _t(13)});
  });

  test('leaves out the places inside a missing-time chunk', () {
    // Two times for three runners: which of the three has no time is exactly
    // what is in dispute.
    final times = settledTimesByPlace([
      _chunk(0, [10, 11], type: ConflictType.missingTime, offBy: 1),
    ]);

    expect(times, isEmpty);
  });

  test('leaves out the places inside an extra-time chunk', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11, 12], type: ConflictType.extraTime, offBy: 1),
    ]);

    expect(times, isEmpty);
  });

  test('places after a flagged stretch still line up', () {
    // The flagged chunk holds three finishers even though which time belongs
    // to which is unsettled, so the next chunk starts at 4th.
    final times = settledTimesByPlace([
      _chunk(0, [10, 11], type: ConflictType.missingTime, offBy: 1),
      _chunk(1, [13, 14]),
    ]);

    expect(times, {4: _t(13), 5: _t(14)});
  });

  test('places before a flagged stretch line up too', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11]),
      _chunk(1, [12], type: ConflictType.missingTime, offBy: 1),
      _chunk(2, [15]),
    ]);

    expect(times, {1: _t(10), 2: _t(11), 5: _t(15)});
  });

  test('an extra time shifts the places after it back', () {
    // Three times but only two runners, so the next chunk starts at 3rd.
    final times = settledTimesByPlace([
      _chunk(0, [10, 11, 12], type: ConflictType.extraTime, offBy: 1),
      _chunk(1, [13]),
    ]);

    expect(times, {3: _t(13)});
  });

  test('treats a chunk still holding a TBD as unsettled', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11],
          type: ConflictType.missingTime,
          offBy: 0,
          rawTimes: [_t(10), 'TBD']),
    ]);

    expect(times, isEmpty, reason: 'TBD is not a time to show anyone');
  });

  test('counts a missing-time chunk as settled once every time is entered', () {
    final times = settledTimesByPlace([
      _chunk(0, [10, 11], type: ConflictType.missingTime, offBy: 0),
    ]);

    expect(times, {1: _t(10), 2: _t(11)});
  });

  test('has nothing to say about an empty race', () {
    expect(settledTimesByPlace([]), isEmpty);
  });
}
