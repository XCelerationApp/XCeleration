import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart' show CoachTimingDataConverter;
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/core/utils/enums.dart';

MergeConflictsController _makeController({
  required List<TimingDatum> timingData,
  required TimingDatum conflictRecord,
  required List<RaceRunner> runners,
  int chunkId = 0,
}) {
  final chunk = TimingChunk(
    id: chunkId,
    timingData: timingData,
    conflictRecord: conflictRecord,
  );
  return MergeConflictsController(
    masterRace: MasterRace.getInstance(chunkId),
    timingChunks: [chunk],
    raceRunners: runners,
  );
}

void main() {
  group('MergeConflictsController.insertTbdAt', () {
    late List<RaceRunner> testRunners;

    setUp(() {
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
      final timingData =
          ['1.0', '2.0', '4.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
      );

      controller.insertTbdAt(0, 1);

      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '4.0']));
    });

    test('handles multiple TBD entries correctly', () {
      final timingData =
          ['1.0', '3.0', '5.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '5.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 1,
      );

      controller.insertTbdAt(1, 1);

      // Initial: ['1.0', '3.0', '5.0', 'TBD', 'TBD'] (2 TBDs added by constructor)
      // After insertTbdAt(1, 1): move first TBD to position 1
      // Result: ['1.0', 'TBD', '3.0', '5.0', 'TBD']
      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '3.0', '5.0', 'TBD']));
    });

    test('handles case where clicking on first time entry', () {
      final timingData =
          ['1.0', '2.0', '3.0'].map((time) => TimingDatum(time: time)).toList();
      final conflictRecord = TimingDatum(
        time: '3.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 2,
      );

      controller.insertTbdAt(2, 0);

      expect(controller.uiChunks.first.times,
          equals(['TBD', '1.0', '2.0', '3.0']));
    });

    test('works with offBy > 1', () {
      final timingData = ['1.0', '2.0', '4.0', '6.0']
          .map((time) => TimingDatum(time: time))
          .toList();
      final conflictRecord = TimingDatum(
        time: '6.0',
        conflict: Conflict(type: ConflictType.missingTime, offBy: 2),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 3,
      );

      controller.insertTbdAt(3, 1);

      // Initial: ['1.0', '2.0', '4.0', '6.0', 'TBD', 'TBD']
      // After insertTbdAt(3, 1): move first TBD to position 1
      // Result: ['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD']
      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '4.0', '6.0', 'TBD']));
    });

    test('handles edge case where conflict is confirmRunner', () {
      final timingData = ['1.0', '2.0', '3.0', '4.0']
          .map((time) => TimingDatum(time: time))
          .toList();
      final conflictRecord = TimingDatum(
        time: '4.0',
        conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
      );

      final controller = _makeController(
        timingData: timingData,
        conflictRecord: conflictRecord,
        runners: testRunners,
        chunkId: 4,
      );

      controller.insertTbdAt(4, 1);

      // For confirmRunner: inserts new TBD record at position 1
      expect(controller.uiChunks.first.times,
          equals(['1.0', 'TBD', '2.0', '3.0', '4.0']));
    });
  });

  group('UIChunk.convertToUIChunks', () {
    test('converts timing chunks to UI chunks correctly', () {
      final runners = List.generate(
          3,
          (i) => RaceRunner(
                raceId: 1,
                runner: Runner(
                  runnerId: i + 1,
                  name: 'Runner ${i + 1}',
                  grade: 10,
                  bibNumber: (i + 1).toString(),
                ),
                team: Team(teamId: 1, name: 'Team', abbreviation: 'T'),
              ));

      final timingChunks = [
        TimingChunk(
          id: 10,
          timingData: ['1.0', '2.0'].map((t) => TimingDatum(time: t)).toList(),
          conflictRecord: TimingDatum(
            time: '2.0',
            conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
          ),
        ),
      ];

      final uiChunks =
          CoachTimingDataConverter.convertToUIChunks(timingChunks, runners);

      expect(uiChunks.length, equals(1));
      expect(uiChunks.first.chunkId, equals(10));
      expect(uiChunks.first.times, equals(['1.0', '2.0']));
    });
  });
}
