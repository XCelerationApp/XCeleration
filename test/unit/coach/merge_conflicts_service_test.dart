import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/services/merge_conflicts_service.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import 'package:xceleration/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter/material.dart';

void main() {
  group('MergeConflictsService', () {
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
        resolveTooManyRunnerTimes: (a, b, c) async => ResolveInformation(
          conflictingRunners: [],
          lastConfirmedPlace: 0,
          availableTimes: [],
          conflictRecord: TimingRecord(place: 0, elapsedTime: ''),
          lastConfirmedRecord: TimingRecord(place: 0, elapsedTime: ''),
          bibData: [],
        ),
        resolveTooFewRunnerTimes: (a, b, c) async => ResolveInformation(
          conflictingRunners: [],
          lastConfirmedPlace: 0,
          availableTimes: [],
          conflictRecord: TimingRecord(place: 0, elapsedTime: ''),
          lastConfirmedRecord: TimingRecord(place: 0, elapsedTime: ''),
          bibData: [],
        ),
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
    
    // test('resolveTooManyRunnerTimes throws exception with invalid numTimes', () async {
    //   // Create runner records (at least 12 runners to cover the places we need)
    //   final runners = List.generate(15, (i) => RunnerRecord(
    //     runnerId: i+1,
    //     raceId: 1,
    //     bib: (i+1).toString(),
    //     name: 'Runner ${i+1}',
    //     grade: 10,
    //     school: 'School',
    //   ));

    //   // Create timing records with a specific pattern to trigger the error
    //   final records = [
    //     // Records 0-9 (normal runner times)
    //     ...List.generate(10, (i) => TimingRecord(
    //       elapsedTime: '${i+1}.0',
    //       type: RecordType.runnerTime,
    //       place: i+1,
    //     )),
        
    //     // Record 10: confirmed record at place 11
    //     TimingRecord(
    //       elapsedTime: '11.0',
    //       type: RecordType.confirmRunner,
    //       place: 11,
    //       isConfirmed: true,
    //     ),
        
    //     // Records 11-14 (some runner times after the confirmed record)
    //     ...List.generate(4, (i) => TimingRecord(
    //       elapsedTime: '${12+i}.0',
    //       type: RecordType.runnerTime,
    //       place: 12+i,
    //     )),
        
    //     // Record 15: extraRunner with numTimes = 5 (less than lastConfirmedPlace)
    //     TimingRecord(
    //       elapsedTime: '16.0',
    //       type: RecordType.extraRunner,
    //       place: 15,
    //       conflict: ConflictDetails(
    //         type: RecordType.extraRunner,
    //         data: {'offBy': 1, 'numTimes': 5}, // Key part: numTimes less than lastConfirmedPlace
    //       ),
    //     ),
    //   ];
      
    //   final timingData = TimingData(records: records, endTime: '16.0', startTime: null);
      
    //   // Call resolveTooManyRunnerTimes directly with the conflict index
    //   // This should now throw an exception due to invalid numTimes value
    //   expect(
    //     () async => await MergeConflictsService.resolveTooManyRunnerTimes(
    //       15, // Index of the extraRunner record
    //       timingData,
    //       runners,
    //     ),
    //     throwsException,
    //   );
    // });
    
    test('resolveTooManyRunnerTimes handles valid scenario with proper inputs', () async {
      // Create runner records
      final runners = List.generate(4, (i) => RunnerRecord(
        runnerId: i+9,
        raceId: 1,
        bib: (i+9).toString(),
        name: 'Runner ${i+9}',
        grade: 10,
        school: 'School',
      ));

      // Create timing records with a valid scenario
      final records = [
        // Records 0-7 (normal runner times)
        ...List.generate(8, (i) => TimingRecord(
          elapsedTime: '${i+1}.0',
          type: RecordType.runnerTime,
          place: i+1,
        )),
        
        // Record 8: last confirmed record at place 8
        TimingRecord(
          elapsedTime: '8.0',
          type: RecordType.confirmRunner,
          place: 8,
          isConfirmed: true,
        ),
        
        // Records 9-12 (times without places)
        ...List.generate(4, (i) => TimingRecord(
          elapsedTime: '${9+i}.0',
          type: RecordType.runnerTime,
        )),
        
        // Record 13: extraRunner with numTimes = 12 (greater than lastConfirmedPlace)
        TimingRecord(
          elapsedTime: '13.0',
          type: RecordType.extraRunner,
          place: 12,
          conflict: ConflictDetails(
            type: RecordType.extraRunner,
            data: {'offBy': 1, 'numTimes': 12},
          ),
        ),
      ];
      
      final timingData = TimingData(records: records, endTime: '13.0', startTime: null);
      
      // Call resolveTooManyRunnerTimes directly with the conflict index
      final resolveInfo = await MergeConflictsService.resolveTooManyRunnerTimes(
        13, // Index of the extraRunner record
        timingData,
        runners,
      );
      
      // Verify the result has the expected values
      expect(resolveInfo.lastConfirmedPlace, equals(8));
      expect(resolveInfo.conflictingRunners.length, equals(4)); // Runners 9-12
      expect(resolveInfo.availableTimes.length, equals(4)); // Times for places 9-12
      
      // Check specific runners in the conflicting runners list
      expect(resolveInfo.conflictingRunners.map((r) => r.bib).toList(), 
             equals(['9', '10', '11', '12']));
    });

    // Note: We removed the test case for 'no conflicting records' as the function is always called with a conflict record

    // test('resolveTooFewRunnerTimes throws exception with invalid range case', () async {
    //   // Create runner records
    //   final runners = List.generate(15, (i) => RunnerRecord(
    //     runnerId: i+1,
    //     raceId: 1,
    //     bib: (i+1).toString(),
    //     name: 'Runner ${i+1}',
    //     grade: 10,
    //     school: 'School',
    //   ));

    //   // Create timing records to trigger the invalid range in resolveTooFewRunnerTimes
    //   final records = [
    //     // First 10 records as normal runner times
    //     ...List.generate(10, (i) => TimingRecord(
    //       elapsedTime: '${i+1}.0',
    //       type: RecordType.runnerTime,
    //       place: i+1,
    //     )),
        
    //     // Record 10: confirmed record at place 11
    //     TimingRecord(
    //       elapsedTime: '11.0',
    //       type: RecordType.confirmRunner,
    //       place: 11,
    //       isConfirmed: true,
    //     ),
        
    //     // Add a missingRunner conflict where the calculation will result in an invalid range
    //     TimingRecord(
    //       elapsedTime: '12.0',
    //       type: RecordType.missingRunner,
    //       place: 5, // A place less than the lastConfirmedPlace
    //       conflict: ConflictDetails(
    //         type: RecordType.missingRunner,
    //         data: {'offBy': 1, 'numTimes': 5},
    //       ),
    //     ),
    //   ];
      
    //   final timingData = TimingData(records: records, endTime: '12.0', startTime: null);
      
    //   // Now that the function throws an exception for invalid ranges, expect an exception
    //   expect(
    //     () async => await MergeConflictsService.resolveTooFewRunnerTimes(
    //       11, // Index of the missingRunner record
    //       timingData,
    //       runners,
    //     ),
    //     throwsException,
    //   );
    // });

    test('clearAllConflicts properly resolves all conflicts', () {
      // Create timing records with various conflicts
      final records = [
        TimingRecord(elapsedTime: '1.0', type: RecordType.runnerTime, place: 1, isConfirmed: false),
        TimingRecord(elapsedTime: '1.2', type: RecordType.runnerTime, place: 2, isConfirmed: false),
        TimingRecord(
          elapsedTime: '2.0', 
          type: RecordType.missingRunner, 
          place: 3,
          conflict: ConflictDetails(type: RecordType.missingRunner, data: {'offBy': 1}),
        ),
        TimingRecord(
          elapsedTime: '3.0', 
          type: RecordType.extraRunner, 
          place: 4,
          conflict: ConflictDetails(type: RecordType.extraRunner, data: {'offBy': 1}),
        ),
      ];
      
      final timingData = TimingData(records: records, endTime: '3.0', startTime: null);
      
      // Clear all conflicts
      MergeConflictsService.clearAllConflicts(timingData);
      
      // Verify all conflicts are resolved
      for (final record in timingData.records) {
        expect(record.conflict, isNull);
        expect(record.isConfirmed, isTrue);
        if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
          expect(record.type, RecordType.confirmRunner);
          expect(record.textColor, Colors.green);
        }
        expect(record.place, isNotNull);
      }
    });
  });
} 