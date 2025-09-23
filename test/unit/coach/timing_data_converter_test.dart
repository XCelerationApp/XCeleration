import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('UIChunk insertTimeAt', () {
    late List<RaceRunner> testRunners;

    setUp(() {
      // Create test runners
      testRunners = List.generate(
          10,
          (i) => RaceRunner(
                raceId: 1,
                runner: Runner(
                  runnerId: i + 1,
                  name: 'Runner ${i + 1}',
                  grade: 10,
                  bibNumber: (i + 1).toString(),
                ),
                team: Team(
                  teamId: 1,
                  name: 'Team',
                  abbreviation: 'T',
                ),
              ));
    });

    test('inserts TBD and removes first TBD when clicking on actual time', () {
      // Create timing data without TBD
      final timingData =
          ['1.0', '2.0', '4.0'].map((time) => TimingDatum(time: time)).toList();

      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final timingChunk = TimingChunk(
        timingData: timingData,
        conflictRecord: conflictRecord,
      );

      final uiChunk = UIChunk(
        timingChunkHash: timingChunk.hashCode,
        times: timingData.map((e) => e.time).toList(),
        allRunners: testRunners,
        conflictRecord: conflictRecord,
        startingPlace: 1,
        controller: null,
        chunkIndex: 0,
      );

      // Click on the "2.0" entry (index 1)
      uiChunk.insertTimeAt(1);

      // Should insert TBD at position 1 and remove the first TBD
      expect(uiChunk.times, equals(['1.0', 'TBD', '2.0', '4.0']));
    });

    test('handles multiple TBD entries correctly', () {
      // Create timing data with offBy = 2
      final timingData =
          ['1.0', '3.0', '5.0'].map((time) => TimingDatum(time: time)).toList();

      final conflictRecord = TimingDatum(
        time: '5.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final timingChunk = TimingChunk(
        timingData: timingData,
        conflictRecord: conflictRecord,
      );

      final uiChunk = UIChunk(
        timingChunkHash: timingChunk.hashCode,
        times: timingData.map((e) => e.time).toList(),
        allRunners: testRunners,
        conflictRecord: conflictRecord,
        startingPlace: 1,
        controller: null,
        chunkIndex: 0,
      );

      // Click on the "3.0" entry (index 1)
      uiChunk.insertTimeAt(1);

      // Should insert TBD at position 1 and remove the last TBD
      // Initial: ['1.0', '3.0', '5.0', 'TBD', 'TBD'] (2 TBDs added by constructor)
      // After insert at 1: ['1.0', 'TBD', '3.0', '5.0', 'TBD', 'TBD']
      // After remove last TBD: ['1.0', 'TBD', '3.0', '5.0', 'TBD']
      expect(uiChunk.times, equals(['1.0', 'TBD', '3.0', '5.0', 'TBD']));
    });

    test('handles case where clicking on first time entry', () {
      // Create timing data with offBy = 1
      final timingData =
          ['1.0', '2.0', '3.0'].map((time) => TimingDatum(time: time)).toList();

      final conflictRecord = TimingDatum(
        time: '3.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final timingChunk = TimingChunk(
        timingData: timingData,
        conflictRecord: conflictRecord,
      );

      final uiChunk = UIChunk(
        timingChunkHash: timingChunk.hashCode,
        times: timingData.map((e) => e.time).toList(),
        allRunners: testRunners,
        conflictRecord: conflictRecord,
        startingPlace: 1,
        controller: null,
        chunkIndex: 0,
      );

      // Click on the first entry "1.0" (index 0)
      uiChunk.insertTimeAt(0);

      // Should insert TBD at the beginning and remove the first TBD
      expect(uiChunk.times, equals(['TBD', '1.0', '2.0', '3.0']));
    });

    test('works with offBy > 1', () {
      // Create timing data with offBy = 2
      final timingData = ['1.0', '2.0', '4.0', '6.0']
          .map((time) => TimingDatum(time: time))
          .toList();

      final conflictRecord = TimingDatum(
        time: '6.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final timingChunk = TimingChunk(
        timingData: timingData,
        conflictRecord: conflictRecord,
      );

      final uiChunk = UIChunk(
        timingChunkHash: timingChunk.hashCode,
        times: timingData.map((e) => e.time).toList(),
        allRunners: testRunners,
        conflictRecord: conflictRecord,
        startingPlace: 1,
        controller: null,
        chunkIndex: 0,
      );

      // Click on the "2.0" entry (index 1)
      uiChunk.insertTimeAt(1);

      // Should insert TBD at position 1 and remove the first TBD
      // Initial: ['1.0', '2.0', '4.0', '6.0', 'TBD', 'TBD'] (2 TBDs added by constructor)
      // After insert at 1: ['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD', 'TBD']
      // After remove first TBD: ['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD']
      expect(uiChunk.times, equals(['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD']));
    });

    test('handles edge case where there are no TBD entries', () {
      // Create timing data with no missing times (confirmRunner conflict)
      final timingData = ['1.0', '2.0', '3.0', '4.0']
          .map((time) => TimingDatum(time: time))
          .toList();

      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
      );

      final timingChunk = TimingChunk(
        timingData: timingData,
        conflictRecord: conflictRecord,
      );

      final uiChunk = UIChunk(
        timingChunkHash: timingChunk.hashCode,
        times: timingData.map((e) => e.time).toList(),
        allRunners: testRunners,
        conflictRecord: conflictRecord,
        startingPlace: 1,
        controller: null,
        chunkIndex: 0,
      );

      // Click on the "2.0" entry (index 1)
      uiChunk.insertTimeAt(1);

      // For confirmRunner conflicts, should just insert TBD since there are no TBDs to remove
      expect(uiChunk.times, equals(['1.0', 'TBD', '2.0', '3.0', '4.0']));
    });
  });
}
