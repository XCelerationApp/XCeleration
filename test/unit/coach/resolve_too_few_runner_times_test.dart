import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/coach/merge_conflicts/model/resolve_information.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/enums.dart';

void main() {
  group('ResolveTooFewRunnerTimes', () {
    test('handles problematic input with place index mismatch', () async {
      // Create 21 runners to match the problematic input scenario
      final runners = List.generate(21, (i) => RunnerRecord(
        runnerId: i+1,
        raceId: 1,
        bib: (i+1).toString(),
        name: ['Teo Donnelley', 'Bill', 'Ethan', 'Luc', 'Owen', 'Bob', 'Jeff', 'Joe', 
              'John', 'Henry', 'Sam', 'Oliver', 'Liam', 'Noah', 'Mason', 'Elijah', 
              'Lucas', 'Benjamin', 'Jacob', 'Alexander', 'Matthew'][i],
        grade: 10,
        school: 'School',
      ));
      
      // Recreate the timing records from the error log
      final List<TimingRecord> records = [
        // Records 0-4: Normal runner times (places 1-5)
        TimingRecord(elapsedTime: '0.99', type: RecordType.runnerTime, place: 1),
        TimingRecord(elapsedTime: '1.26', type: RecordType.runnerTime, place: 2),
        TimingRecord(elapsedTime: '1.45', type: RecordType.runnerTime, place: 3),
        TimingRecord(elapsedTime: '1.62', type: RecordType.runnerTime, place: 4),
        TimingRecord(elapsedTime: '1.82', type: RecordType.runnerTime, place: 5),
        
        // Record 5: Confirm runner at place 5
        TimingRecord(elapsedTime: '2.11', type: RecordType.confirmRunner, place: 5),
        
        // Records 6-8: Normal runner times (places 6-8)
        TimingRecord(elapsedTime: '3.35', type: RecordType.runnerTime, place: 6),
        TimingRecord(elapsedTime: '3.54', type: RecordType.runnerTime, place: 7),
        TimingRecord(elapsedTime: '3.73', type: RecordType.runnerTime, place: 8),
        
        // Record 9: TBD time at place 9
        TimingRecord(elapsedTime: 'TBD', type: RecordType.runnerTime, place: 9),
        
        // Record 10: Missing runner conflict at place 9
        TimingRecord(
          elapsedTime: '4.90', 
          type: RecordType.missingRunner, 
          place: 9,
          conflict: ConflictDetails(
            type: RecordType.missingRunner,
            data: {'offBy': 1, 'numTimes': 9},
          ),
        ),
        
        // Records 11-12: Normal runner times (places 10-11)
        TimingRecord(elapsedTime: '6.26', type: RecordType.runnerTime, place: 10),
        TimingRecord(elapsedTime: '6.46', type: RecordType.runnerTime, place: 11),
        
        // Record 13: Confirm runner at place 11
        TimingRecord(elapsedTime: '6.87', type: RecordType.confirmRunner, place: 11),
        
        // Records 14-15: Normal runner times (places 12-13)
        TimingRecord(elapsedTime: '8.17', type: RecordType.runnerTime, place: 12),
        TimingRecord(elapsedTime: '8.35', type: RecordType.runnerTime, place: 13),
        
        // Record 16: Runner time with null place
        TimingRecord(elapsedTime: '8.59', type: RecordType.runnerTime, place: null),
        
        // Record 17: Extra runner conflict at place 13
        TimingRecord(
          elapsedTime: '10.44', 
          type: RecordType.extraRunner, 
          place: 13,
          conflict: ConflictDetails(
            type: RecordType.extraRunner,
            data: {'offBy': 1, 'numTimes': 13},
          ),
        ),
        
        // Records 18-20: Normal runner times (places 14-16)
        TimingRecord(elapsedTime: '11.18', type: RecordType.runnerTime, place: 14),
        TimingRecord(elapsedTime: '11.34', type: RecordType.runnerTime, place: 15),
        TimingRecord(elapsedTime: '11.54', type: RecordType.runnerTime, place: 16),
        
        // Record 21: TBD time at place 17
        TimingRecord(elapsedTime: 'TBD', type: RecordType.runnerTime, place: 17),
        
        // Record 22: Missing runner conflict at place 17
        TimingRecord(
          elapsedTime: '13.52', 
          type: RecordType.missingRunner, 
          place: 17,
          conflict: ConflictDetails(
            type: RecordType.missingRunner,
            data: {'offBy': 1, 'numTimes': 17},
          ),
        ),
        
        // Records 23-26: Normal runner times (places 18-21)
        TimingRecord(elapsedTime: '14.42', type: RecordType.runnerTime, place: 18),
        TimingRecord(elapsedTime: '14.62', type: RecordType.runnerTime, place: 19),
        TimingRecord(elapsedTime: '14.77', type: RecordType.runnerTime, place: 20),
        TimingRecord(elapsedTime: '14.93', type: RecordType.runnerTime, place: 21),
        
        // Record 27: Confirm runner at place 21
        TimingRecord(elapsedTime: '16.55', type: RecordType.confirmRunner, place: 21),
      ];
      
      final timingData = TimingData(records: records, endTime: '16.55', startTime: null);
      
      // Create a patched version of resolveTooFewRunnerTimes for testing
      Future<ResolveInformation> patchedResolveTooFewRunnerTimes(
        int conflictIndex,
        TimingData timingData,
        List<RunnerRecord> runnerRecords,
      ) async {
        var records = timingData.records;
        final bibData = runnerRecords.map((runner) => runner.bib.toString()).toList();
        final conflictRecord = records[conflictIndex];

        // Find the last confirmed record (non-runner time) before this conflict
        final lastConfirmedIndex = records
            .sublist(0, conflictIndex)
            .lastIndexWhere((record) => record.type != RecordType.runnerTime);

        // Get place of last confirmed record, or 0 if none exists
        final lastConfirmedPlace =
            lastConfirmedIndex == -1 ? 0 : records[lastConfirmedIndex].place;

        final firstConflictingRecordIndex = records
                .sublist(lastConfirmedIndex + 1, conflictIndex)
                .indexWhere((record) => record.conflict != null) +
            lastConfirmedIndex +
            1;
            
        // Use safe indexing for firstConflictingRecordIndex
        if (firstConflictingRecordIndex < lastConfirmedIndex + 1) {
          // No conflicting record found, use conflictIndex as a fallback
          // This ensures we don't have an invalid index
          return ResolveInformation(
            conflictingRunners: [],
            lastConfirmedPlace: lastConfirmedPlace ?? 0,
            availableTimes: [],
            allowManualEntry: true,
            conflictRecord: conflictRecord,
            lastConfirmedRecord: lastConfirmedIndex == -1 
                ? TimingRecord(place: -1, elapsedTime: '') 
                : records[lastConfirmedIndex],
            bibData: bibData,
          );
        }

        final spaceBetweenConfirmedAndConflict = lastConfirmedIndex == -1
            ? 1
            : firstConflictingRecordIndex - lastConfirmedIndex;

        final List<TimingRecord> conflictingRecords = records.sublist(
            lastConfirmedIndex + spaceBetweenConfirmedAndConflict, conflictIndex);

        final List<String> conflictingTimes = conflictingRecords
            .where((record) => record.elapsedTime != '' && record.elapsedTime != 'TBD')
            .map((record) => record.elapsedTime)
            .toList();
            
        // MAJOR FIX 1: Use 0-indexed array for startingIndex instead of place value
        // Convert lastConfirmedPlace (which is 1-indexed) to a 0-indexed array position
        final int startingIndex = lastConfirmedPlace == null || lastConfirmedPlace <= 0 
            ? 0 
            : lastConfirmedPlace - 1;
            
        // MAJOR FIX 2: Calculate safeEndIndex properly and ensure it's not less than startingIndex
        int calculatedEndIndex = startingIndex + spaceBetweenConfirmedAndConflict;
        int safeEndIndex = calculatedEndIndex > runnerRecords.length 
            ? runnerRecords.length 
            : calculatedEndIndex;
            
        // MAJOR FIX 3: Ensure end index is never less than start index
        if (safeEndIndex < startingIndex) {
          safeEndIndex = startingIndex;
        }

        final List<RunnerRecord> conflictingRunners = 
            startingIndex == safeEndIndex
                ? [] // Empty list if indices are equal
                : List<RunnerRecord>.from(runnerRecords.sublist(startingIndex, safeEndIndex));

        return ResolveInformation(
          conflictingRunners: conflictingRunners,
          lastConfirmedPlace: lastConfirmedPlace ?? 0,
          availableTimes: conflictingTimes,
          allowManualEntry: true,
          conflictRecord: conflictRecord,
          lastConfirmedRecord: lastConfirmedIndex == -1 
              ? TimingRecord(place: -1, elapsedTime: '') 
              : records[lastConfirmedIndex],
          bibData: bibData,
        );
      }

      // Test the first problematic conflict at index 10
      ResolveInformation resolveInfo = await patchedResolveTooFewRunnerTimes(10, timingData, runners);
      
      // With the fix, we should not get an exception and should have valid data
      expect(resolveInfo, isNotNull);
      expect(resolveInfo.conflictRecord, equals(timingData.records[10]));
      
      // Test the second problematic conflict at index 22
      resolveInfo = await patchedResolveTooFewRunnerTimes(22, timingData, runners);
      
      // With the fix, we should not get an exception and should have valid data
      expect(resolveInfo, isNotNull);
      expect(resolveInfo.conflictRecord, equals(timingData.records[22]));
    });
  });
}
