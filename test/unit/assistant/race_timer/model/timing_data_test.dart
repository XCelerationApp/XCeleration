// import 'package:flutter_test/flutter_test.dart';
// import 'package:xceleration/assistant/race_timer/model/timing_data.dart';
// import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
// import 'package:xceleration/shared/models/timing_records/conflict.dart';
// import 'package:xceleration/core/utils/enums.dart';
// import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

// void main() {
//   group('TimingData.addRunnerTimeRecord', () {
//     test('adds to currentChunk when there is no conflict', () {
//       final timingData = TimingData();
//       expect(timingData.currentChunk.hasConflict, false);
//       expect(timingData.currentChunk.timingData, isEmpty);

//       final record = TimingDatum(time: '0:10.00');
//       timingData.addRunnerTimeRecord(record);

//       expect(timingData.currentChunk.timingData.length, 1);
//       expect(timingData.currentChunk.timingData.first, record);
//       expect(timingData.currentChunk.hasConflict, false);
//     });

//     test('throws if record has a conflict', () {
//       final timingData = TimingData();
//       final record = TimingDatum(
//         time: '0:11.00',
//         conflict: Conflict(type: ConflictType.missingTime),
//       );
//       expect(() => timingData.addRunnerTimeRecord(record), throwsException);
//     });

//     test('caches chunk and starts a new one when current has conflict', () {
//       final timingData = TimingData();

//       // Create a conflict in the current chunk
//       timingData.addConfirmRecord(TimingDatum(
//         time: '0:12.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       ));
//       expect(timingData.currentChunk.hasConflict, true);

//       // Now add a runner time; should cache and start new chunk
//       final record = TimingDatum(time: '0:13.00');
//       timingData.addRunnerTimeRecord(record);

//       expect(timingData.currentChunk.hasConflict, false);
//       expect(timingData.currentChunk.timingData, [record]);
//       // Cached chunk should be present indirectly via hasTimingData
//       expect(timingData.hasTimingData, true);
//     });
//   });

//   group('TimingData conflict record methods', () {
//     test('addConfirmRecord sets or updates confirmRunner conflict', () {
//       final timingData = TimingData();

//       // Set confirm when none exists
//       final confirm1 = TimingDatum(
//         time: '0:30.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       );
//       timingData.addConfirmRecord(confirm1);
//       expect(timingData.currentChunk.hasConflict, true);
//       expect(timingData.currentChunk.conflictRecord, confirm1);

//       // Update time if same conflict type
//       final confirm2 = TimingDatum(
//         time: '0:31.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       );
//       timingData.addConfirmRecord(confirm2);
//       expect(timingData.currentChunk.conflictRecord!.time, '0:31.00');

//       // Cache and replace if previous conflict type differs
//       final missing = TimingDatum(
//         time: '0:32.00',
//         conflict: Conflict(type: ConflictType.missingTime),
//       );
//       timingData.addMissingTimeRecord(missing);
//       // Now adding confirm should cache and replace
//       final confirm3 = TimingDatum(
//         time: '0:33.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       );
//       timingData.addConfirmRecord(confirm3);
//       expect(timingData.currentChunk.conflictRecord, confirm3);
//     });

//     test('addMissingTimeRecord sets, increments offBy, or reduces extraTime',
//         () {
//       final timingData = TimingData();

//       // Set missing when none exists
//       final missing1 = TimingDatum(
//         time: '0:40.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
//       );
//       timingData.addMissingTimeRecord(missing1);
//       expect(timingData.currentChunk.conflictRecord, isNotNull);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.type,
//           ConflictType.missingTime);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);

//       // Increment offBy when same conflict type
//       final missing2 = TimingDatum(
//         time: '0:41.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
//       );
//       timingData.addMissingTimeRecord(missing2);
//       expect(timingData.currentChunk.conflictRecord!.time, '0:41.00');
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 2);

//       // If current is extraTime, reduce by one
//       final extra = TimingDatum(
//         time: '0:42.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 2),
//       );
//       // Force set to extraTime by using addExtraTimeRecord
//       final td2 = TimingData();
//       td2.addExtraTimeRecord(extra);
//       expect(td2.currentChunk.conflictRecord!.conflict!.offBy, 2);
//       // Now adding missing should reduce
//       final missingReduce = TimingDatum(
//         time: '0:43.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
//       );
//       td2.addMissingTimeRecord(missingReduce);
//       expect(td2.currentChunk.conflictRecord!.conflict!.offBy, 1);
//       expect(td2.currentChunk.conflictRecord!.time, '0:43.00');
//     });

//     test('addExtraTimeRecord sets, increments offBy, or reduces missingTime',
//         () {
//       final timingData = TimingData();

//       // Set extra when none exists
//       final extra1 = TimingDatum(
//         time: '0:50.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
//       );
//       timingData.addExtraTimeRecord(extra1);
//       expect(timingData.currentChunk.conflictRecord, isNotNull);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.type,
//           ConflictType.extraTime);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);

//       // Increment offBy when same conflict type
//       final extra2 = TimingDatum(
//         time: '0:51.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
//       );
//       timingData.addExtraTimeRecord(extra2);
//       expect(timingData.currentChunk.conflictRecord!.time, '0:51.00');
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 2);

//       // If current is missingTime, reduce by one
//       final missing = TimingDatum(
//         time: '0:52.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
//       );
//       final td2 = TimingData();
//       td2.addMissingTimeRecord(missing);
//       expect(td2.currentChunk.conflictRecord!.conflict!.offBy, 2);
//       // Now adding extra should reduce
//       final extraReduce = TimingDatum(
//         time: '0:53.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
//       );
//       td2.addExtraTimeRecord(extraReduce);
//       expect(td2.currentChunk.conflictRecord!.conflict!.offBy, 1);
//       expect(td2.currentChunk.conflictRecord!.time, '0:53.00');
//     });
//   });

//   group('TimingData.reduceCurrentConflictByOne', () {
//     test('decrements offBy and clears conflict at zero', () {
//       final timingData = TimingData();
//       final extra = TimingDatum(
//         time: '1:00.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 2),
//       );
//       timingData.addExtraTimeRecord(extra);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 2);

//       timingData.reduceCurrentConflictByOne();
//       expect(timingData.currentChunk.conflictRecord!.conflict!.offBy, 1);

//       timingData.reduceCurrentConflictByOne();
//       expect(timingData.currentChunk.conflictRecord, isNull);
//     });

//     test('updates time when newTime provided', () {
//       final timingData = TimingData();
//       final missing = TimingDatum(
//         time: '1:10.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
//       );
//       timingData.addMissingTimeRecord(missing);
//       expect(timingData.currentChunk.conflictRecord!.time, '1:10.00');

//       timingData.reduceCurrentConflictByOne(newTime: '1:11.00');
//       expect(timingData.currentChunk.conflictRecord, isNull);
//       // Conflict cleared at zero
//     });
//   });

//   group('TimingData cache and delete current chunk', () {
//     test('cacheCurrentChunk stores and deleteCurrentChunk restores last', () {
//       final timingData = TimingData();

//       // Build first chunk with a conflict
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:05.00'));
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:06.00'));
//       timingData.addConfirmRecord(TimingDatum(
//         time: '0:06.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       ));
//       expect(timingData.currentChunk.hasConflict, true);

//       // Cache it
//       timingData.cacheCurrentChunk();
//       // Start second chunk
//       final second = TimingDatum(time: '0:07.00');
//       timingData.currentChunk = TimingChunk(timingData: [second]);

//       // Delete current should restore the cached chunk
//       timingData.deleteCurrentChunk();
//       expect(timingData.currentChunk.hasConflict, true);
//       expect(timingData.currentChunk.conflictRecord!.conflict!.type,
//           ConflictType.confirmRunner);

//       // Delete again should clear to empty since cache is empty
//       timingData.deleteCurrentChunk();
//       expect(timingData.currentChunk.timingData, isEmpty);
//       expect(timingData.currentChunk.hasConflict, false);
//     });
//   });

//   group('TimingData start/end time and hasTimingData', () {
//     test('changeStartTime and changeEndTime set values and notify', () {
//       final timingData = TimingData();
//       expect(timingData.startTime, isNull);
//       expect(timingData.endTime, isNull);

//       final d = DateTime(2024, 1, 1, 12, 0, 0);
//       timingData.changeStartTime(d);
//       expect(timingData.startTime, d);

//       final dur = Duration(minutes: 5);
//       timingData.changeEndTime(dur);
//       expect(timingData.endTime, dur);
//     });

//     test('hasTimingData reflects presence of data or cached chunks', () {
//       final timingData = TimingData();
//       expect(timingData.hasTimingData, false);

//       // Add a runner record -> true
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
//       expect(timingData.hasTimingData, true);

//       // Clear records -> false
//       timingData.clearRecords();
//       expect(timingData.hasTimingData, false);

//       // Cache a chunk and then empty current -> still true via cache
//       timingData.addConfirmRecord(TimingDatum(
//         time: '0:10.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       ));
//       timingData.cacheCurrentChunk();
//       expect(timingData.hasTimingData, true);

//       // Deleting current chunk should restore from cache; then delete again -> false
//       timingData.deleteCurrentChunk();
//       timingData.deleteCurrentChunk();
//       expect(timingData.hasTimingData, false);
//     });
//   });

//   group('TimingData.encodedRecords', () {
//     test(
//         'encodes current and cached chunks in order, no confirm added to cached',
//         () async {
//       final timingData = TimingData();

//       // Current chunk with no conflict: add two times
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:02.00'));

//       // Set end time (only affects current chunk if it has no conflict at encoding time)
//       timingData.changeEndTime(const Duration(seconds: 2));

//       // Cache current chunk
//       timingData.cacheCurrentChunk();

//       // Start a fresh current chunk so conflicts don't merge with cached
//       timingData.currentChunk = TimingChunk(timingData: []);

//       // Make a new current chunk with a missingTime conflict
//       final missing = TimingDatum(
//         time: '0:03.00',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
//       );
//       timingData.addMissingTimeRecord(missing);

//       final encoded = await timingData.encodedRecords();
//       // Order: cached chunk runner times, then current chunk's missingTime
//       expect(
//         encoded,
//         '0:01.00,0:02.00,MT 2 0:03.00',
//       );
//     });
//   });

//   group('TimingData.uiRecords', () {
//     test(
//         'includes cached chunks and current chunk with correct places and types',
//         () {
//       final timingData = TimingData();

//       // Build and cache first chunk: two runner times -> places 1,2
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:02.00'));
//       timingData.cacheCurrentChunk();

//       // Reset current chunk to avoid merging with cached
//       timingData.currentChunk = TimingChunk(timingData: []);

//       // Current chunk: missingTime with offBy 2; should produce one runner time and two TBDs
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:03.00'));
//       timingData.addMissingTimeRecord(TimingDatum(
//         time: '0:03.50',
//         conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
//       ));

//       final records = timingData.uiRecords;

//       expect(records.length, 5);
//       // Cached
//       expect(records[0].time, '0:01.00');
//       expect(records[0].place, 1);
//       expect(records[1].time, '0:02.00');
//       expect(records[1].place, 2);

//       // Current
//       expect(records[2].time, '0:03.00');
//       expect(records[2].place, 3);
//       expect(records[3].time, 'TBD');
//       expect(records[3].place, 4);
//       expect(records[4].time, 'TBD');
//       expect(records[4].place, 5);
//     });

//     test(
//         'extraTime marks extras with null places and does not increment endingPlace',
//         () {
//       final timingData = TimingData();
//       // Cache an initial runner to set starting place to 2 for current
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
//       timingData.cacheCurrentChunk();

//       // Reset current chunk to avoid merging with cached
//       timingData.currentChunk = TimingChunk(timingData: []);

//       // Current chunk: three times with extraTime offBy 2
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:02.00'));
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:03.00'));
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:04.00'));
//       timingData.addExtraTimeRecord(TimingDatum(
//         time: '0:04.00',
//         conflict: Conflict(type: ConflictType.extraTime, offBy: 2),
//       ));

//       final records = timingData.uiRecords;
//       // Cached: place 1 -> 0:01.00
//       // Current: first (length - offBy) = 1 record gets place 2, rest extras null place
//       expect(records[0].place, 1);
//       expect(records[1].place, 2); // 0:02.00
//       expect(records[2].place, isNull); // 0:03.00 extra
//       expect(records[3].place, isNull); // 0:04.00 extra
//     });
//   });

//   group('TimingData.clearRecords', () {
//     test('resets chunk, cache, converter cache, and start/end times', () {
//       final timingData = TimingData();

//       // Populate
//       timingData.addRunnerTimeRecord(TimingDatum(time: '0:01.00'));
//       timingData.addConfirmRecord(TimingDatum(
//         time: '0:01.00',
//         conflict: Conflict(type: ConflictType.confirmRunner),
//       ));
//       timingData.cacheCurrentChunk();
//       timingData.changeStartTime(DateTime.now());
//       timingData.changeEndTime(const Duration(seconds: 10));
//       expect(timingData.hasTimingData, true);

//       // Clear
//       timingData.clearRecords();

//       // Validate reset
//       expect(timingData.currentChunk.timingData, isEmpty);
//       expect(timingData.currentChunk.hasConflict, false);
//       expect(timingData.startTime, isNull);
//       expect(timingData.endTime, isNull);
//       expect(timingData.hasTimingData, false);
//     });
//   });
// }

void main() {}
