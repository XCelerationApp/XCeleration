import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/timing_records/time_shift.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

// A Timer who pressed Start late makes every time short by the same amount.
// The coach can move them all back into line before saving.

List<TimingChunk> _race() => [
      TimingChunk(id: 0, timingData: [
        TimingDatum(time: '15:01.23'),
        TimingDatum(time: '15:02.00'),
      ], conflictRecord: TimingDatum(
          time: '15:02.00',
          conflict: Conflict(type: ConflictType.confirmRunner, offBy: 2))),
      TimingChunk(id: 1, timingData: [
        TimingDatum(time: 'TBD'),
        TimingDatum(time: '59:58.50'),
      ]),
    ];

List<String> _times(List<TimingChunk> chunks) => [
      for (final c in chunks) ...[
        ...c.timingData.map((d) => d.time),
        if (c.conflictRecord != null) 'confirm ${c.conflictRecord!.time}',
      ],
    ];

void main() {
  test('a late start adds the same seconds to every time', () {
    final chunks = _race();

    expect(shiftTimes(chunks, const Duration(seconds: 5)), isNull);

    expect(_times(chunks), [
      '15:06.23',
      '15:07.00',
      'confirm 15:07.00',
      'TBD',
      '1:00:03.50',
    ]);
  });

  test('an early start takes them off', () {
    final chunks = _race();

    expect(shiftTimes(chunks, const Duration(milliseconds: -1500)), isNull);

    expect(_times(chunks).first, '14:59.73');
  });

  test('a shift below zero moves nothing', () {
    final chunks = [
      TimingChunk(id: 0, timingData: [
        TimingDatum(time: '10.00'),
        TimingDatum(time: '4.50'),
      ]),
    ];

    expect(shiftTimes(chunks, const Duration(seconds: -5)), contains('4.50'));

    expect(_times(chunks), ['10.00', '4.50'],
        reason: 'never left half-moved');
  });
}
