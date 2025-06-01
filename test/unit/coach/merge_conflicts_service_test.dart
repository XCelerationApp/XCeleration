import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/services/merge_conflicts_service.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';

void main() {
  test('createChunks groups records and runners and handles conflicts', () async {
    // Create 5 runners
    final runners = List.generate(5, (i) => RunnerRecord(
      runnerId: i+1,
      raceId: 1,
      bib: (i+1).toString(),
      name: 'Runner ${i+1}',
      grade: 10,
      school: 'School',
    ));

    // Create timing records with a missing runner at place 3
    final records = [
      // Normal runner times
      TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1),
      TimingRecord(elapsedTime: '1.1', type: RecordType.runnerTime, place: 2),

      // Missing runner at place 3 (TBD + conflict)
      TimingRecord(elapsedTime: 'TBD', type: RecordType.runnerTime, place: 3),
      TimingRecord(
        elapsedTime: '2.0',
        type: RecordType.missingRunner,
        place: 3,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          data: {'offBy': 1, 'numTimes': 3},
        ),
      ),

      // Normal runner time
      TimingRecord(elapsedTime: '1.2', type: RecordType.runnerTime, place: 4),

      // Extra runner at place 5 (conflict: extraRunner)
      TimingRecord(
        elapsedTime: '1.25',
        type: RecordType.extraRunner,
        place: 5,
        conflict: ConflictDetails(
          type: RecordType.extraRunner,
          data: {'offBy': 1, 'numTimes': 5},
        ),
      ),
      TimingRecord(elapsedTime: '1.3', type: RecordType.runnerTime, place: 5),

      // Confirm runner at place 6 (conflict: confirmRunner)
      TimingRecord(
        elapsedTime: '1.35',
        type: RecordType.confirmRunner,
        place: 6,
        conflict: ConflictDetails(
          type: RecordType.confirmRunner,
          data: {'offBy': 1, 'numTimes': 6},
        ),
      ),
      TimingRecord(elapsedTime: '1.4', type: RecordType.runnerTime, place: 6),

      // Another missing runner at place 7
      TimingRecord(elapsedTime: 'TBD', type: RecordType.runnerTime, place: 7),
      TimingRecord(
        elapsedTime: '2.5',
        type: RecordType.missingRunner,
        place: 7,
        conflict: ConflictDetails(
          type: RecordType.missingRunner,
          data: {'offBy': 1, 'numTimes': 7},
        ),
      ),

      // Normal runner time at place 8
      TimingRecord(elapsedTime: '1.5', type: RecordType.runnerTime, place: 8),
    ];
    final timingData = TimingData(records: records, endTime: '1.3', startTime: null);

    final chunks = await MergeConflictsService.createChunks(
      timingData: timingData,
      runnerRecords: runners,
      resolveTooManyRunnerTimes: (a, b, c) async => throw UnimplementedError(),
      resolveTooFewRunnerTimes: (a, b, c) async => throw UnimplementedError(),
      selectedTimes: {},
    );

    // Print chunk structure
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      Logger.d('Chunk $i: type=${chunk.type}, records=${chunk.records.length}, runners=${chunk.runners.length}');
      Logger.d('  Record places: ${chunk.records.map((r) => r.place).toList()}');
      Logger.d('  Runner bibs: ${chunk.runners.map((r) => r.bib).toList()}');
    }

    // Assert that all runners are included in some chunk
    final allChunkRunnerBibs = chunks.expand((c) => c.runners.map((r) => r.bib)).toSet();
    final allRunnerBibs = runners.map((r) => r.bib).toSet();
    expect(allChunkRunnerBibs, allRunnerBibs);
    // Assert that the missingRunner conflict is present in one chunk
    expect(chunks.any((c) => c.records.any((r) => r.type == RecordType.missingRunner)), true);
  });
} 