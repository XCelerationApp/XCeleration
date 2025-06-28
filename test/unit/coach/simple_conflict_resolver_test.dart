import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/time_record.dart';
import 'package:xceleration/coach/merge_conflicts/services/simple_conflict_resolver.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('SimpleConflictResolver', () {
    // Helper function to create test time records
    TimeRecord createTimeRecord({
      required String elapsedTime,
      required RecordType type,
      int? place,
      bool isConfirmed = false,
      ConflictDetails? conflict,
    }) {
      return TimeRecord(
        elapsedTime: elapsedTime,
        type: type,
        place: place,
        isConfirmed: isConfirmed,
        conflict: conflict,
      );
    }

    // Helper function to create test runner records
    RunnerRecord createRunnerRecord({
      required int id,
      required String bib,
      required String name,
    }) {
      return RunnerRecord(
        runnerId: id,
        raceId: 1,
        bib: bib,
        name: name,
        grade: 10,
        school: 'Test School',
      );
    }

    group('resolveMissingTimes', () {
      test('successfully resolves missing time conflict', () {
        // Arrange: Create timing records with missing time
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: true,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
            isConfirmed: true,
          ),
          createTimeRecord(
            elapsedTime: 'TBD',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
            conflict: ConflictDetails(
              type: RecordType.missingTime,
              data: {'offBy': 1, 'numTimes': 3},
            ),
          ),
          createTimeRecord(
            elapsedTime: '3.5',
            type: RecordType.missingTime,
            place: 3,
            conflict: ConflictDetails(
              type: RecordType.missingTime,
              data: {'offBy': 1, 'numTimes': 3},
            ),
          ),
          createTimeRecord(
            elapsedTime: '4.0',
            type: RecordType.runnerTime,
            place: 4,
            isConfirmed: true,
          ),
        ];

        final runners = [
          createRunnerRecord(id: 1, bib: '1', name: 'Runner 1'),
          createRunnerRecord(id: 2, bib: '2', name: 'Runner 2'),
          createRunnerRecord(id: 3, bib: '3', name: 'Runner 3'),
        ];

        // Act: Resolve missing time
        final result = SimpleConflictResolver.resolveMissingTimes(
          timingRecords: records,
          runners: runners,
          userTimes: ['3.0'],
          conflictPlace: 3,
        );

        // Assert: Check that TBD record was updated
        final updatedTBDRecord = result.firstWhere(
          (r) => r.place == 3 && r.type == RecordType.runnerTime,
        );
        expect(updatedTBDRecord.elapsedTime, equals('3.0'));
        expect(updatedTBDRecord.isConfirmed, isTrue);
        expect(updatedTBDRecord.conflict, isNull);

        // Assert: Check that missing time record was converted to confirmRunner
        final confirmRecord = result.firstWhere(
          (r) => r.type == RecordType.confirmRunner,
        );
        expect(confirmRecord.isConfirmed, isTrue);
        expect(confirmRecord.conflict, isNull);
      });

      test('handles multiple missing times correctly', () {
        // Arrange: Create records with multiple missing times
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: true,
          ),
          createTimeRecord(
            elapsedTime: 'TBD',
            type: RecordType.runnerTime,
            place: 2,
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
          createTimeRecord(
            elapsedTime: 'TBD',
            type: RecordType.runnerTime,
            place: 3,
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
          createTimeRecord(
            elapsedTime: '4.0',
            type: RecordType.missingTime,
            place: 3,
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
        ];

        final runners = [
          createRunnerRecord(id: 1, bib: '1', name: 'Runner 1'),
          createRunnerRecord(id: 2, bib: '2', name: 'Runner 2'),
        ];

        // Act: Resolve with multiple times
        final result = SimpleConflictResolver.resolveMissingTimes(
          timingRecords: records,
          runners: runners,
          userTimes: ['2.0', '3.0'],
          conflictPlace: 2,
        );

        // Assert: Both TBD records should be updated
        final place2Record = result.firstWhere(
          (r) => r.place == 2 && r.type == RecordType.runnerTime,
        );
        final place3Record = result.firstWhere(
          (r) => r.place == 3 && r.type == RecordType.runnerTime,
        );

        expect(place2Record.elapsedTime, equals('2.0'));
        expect(place3Record.elapsedTime, equals('3.0'));
        expect(place2Record.isConfirmed, isTrue);
        expect(place3Record.isConfirmed, isTrue);
      });
    });

    group('resolveExtraTimes', () {
      test('successfully removes extra times', () {
        // Arrange: Create records with extra times
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: true,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
            isConfirmed: false,
            conflict: ConflictDetails(type: RecordType.extraTime),
          ),
          createTimeRecord(
            elapsedTime: '2.5',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
            conflict: ConflictDetails(type: RecordType.extraTime),
          ),
          createTimeRecord(
            elapsedTime: '3.0',
            type: RecordType.extraTime,
            place: 2,
            conflict: ConflictDetails(type: RecordType.extraTime),
          ),
        ];

        // Act: Remove the extra time
        final result = SimpleConflictResolver.resolveExtraTimes(
          timingRecords: records,
          timesToRemove: ['2.5'],
          conflictPlace: 2,
        );

        // Assert: Extra time should be removed
        expect(result.any((r) => r.elapsedTime == '2.5'), isFalse);

        // Assert: Remaining records should have conflicts cleared
        final remainingRecords = result.where(
          (r) => r.conflict?.type == RecordType.extraTime,
        );
        expect(remainingRecords.length, equals(0));

        // Assert: Places should be updated sequentially
        final runnerTimeRecords =
            result.where((r) => r.type == RecordType.runnerTime).toList();
        runnerTimeRecords.sort((a, b) => a.place!.compareTo(b.place!));

        for (int i = 0; i < runnerTimeRecords.length; i++) {
          expect(runnerTimeRecords[i].place, equals(i + 1));
        }
      });

      test('removes multiple extra times correctly', () {
        // Arrange: Create records with multiple extra times
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
          ),
          createTimeRecord(
            elapsedTime: '2.5',
            type: RecordType.runnerTime,
            place: 3,
          ),
          createTimeRecord(
            elapsedTime: '2.7',
            type: RecordType.runnerTime,
            place: 4,
          ),
          createTimeRecord(
            elapsedTime: '3.0',
            type: RecordType.extraTime,
            place: 2,
            conflict: ConflictDetails(type: RecordType.extraTime),
          ),
        ];

        // Act: Remove multiple times
        final result = SimpleConflictResolver.resolveExtraTimes(
          timingRecords: records,
          timesToRemove: ['2.5', '2.7'],
          conflictPlace: 2,
        );

        // Assert: Both times should be removed
        expect(result.any((r) => r.elapsedTime == '2.5'), isFalse);
        expect(result.any((r) => r.elapsedTime == '2.7'), isFalse);

        // Assert: Remaining runner time records should be sequential
        final runnerTimeRecords =
            result.where((r) => r.type == RecordType.runnerTime).toList();
        expect(runnerTimeRecords.length, equals(2)); // Only 1.0 and 2.0 remain
      });
    });

    group('identifyConflicts', () {
      test('correctly identifies all conflict types', () {
        // Arrange: Create records with various conflicts
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: 'TBD',
            type: RecordType.runnerTime,
            place: 2,
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
          createTimeRecord(
            elapsedTime: '2.5',
            type: RecordType.runnerTime,
            place: 3,
            conflict: ConflictDetails(type: RecordType.extraTime),
          ),
        ];

        // Act: Identify conflicts
        final conflicts = SimpleConflictResolver.identifyConflicts(records);

        // Assert: Should find conflicts
        expect(conflicts.length, equals(2));

        final missingTimeConflict = conflicts.firstWhere(
          (c) => c.type == RecordType.missingTime,
        );
        expect(missingTimeConflict.place, equals(2));
        expect(missingTimeConflict.elapsedTime, equals('TBD'));

        final extraTimeConflict = conflicts.firstWhere(
          (c) => c.type == RecordType.extraTime,
        );
        expect(extraTimeConflict.place, equals(3));
        expect(extraTimeConflict.elapsedTime, equals('2.5'));
      });

      test('returns empty list when no conflicts exist', () {
        // Arrange: Create records without conflicts
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
          ),
        ];

        // Act: Identify conflicts
        final conflicts = SimpleConflictResolver.identifyConflicts(records);

        // Assert: Should find no conflicts
        expect(conflicts, isEmpty);
      });
    });

    group('cleanupDuplicateConfirmations', () {
      test('removes duplicate confirmRunner records', () {
        // Arrange: Create records with duplicate confirmations
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '1.5',
            type: RecordType.confirmRunner,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
          ),
          createTimeRecord(
            elapsedTime: '2.5',
            type: RecordType.confirmRunner,
            place: 1, // Duplicate for place 1
          ),
          createTimeRecord(
            elapsedTime: '3.0',
            type: RecordType.confirmRunner,
            place: 2,
          ),
        ];

        // Act: Clean up duplicates
        final result =
            SimpleConflictResolver.cleanupDuplicateConfirmations(records);

        // Assert: Should keep only last confirm per place
        final confirmRecords =
            result.where((r) => r.type == RecordType.confirmRunner).toList();
        expect(confirmRecords.length, equals(2));

        final place1Confirm = confirmRecords.firstWhere((r) => r.place == 1);
        expect(
            place1Confirm.elapsedTime, equals('2.5')); // Last one for place 1

        final place2Confirm = confirmRecords.firstWhere((r) => r.place == 2);
        expect(place2Confirm.elapsedTime, equals('3.0'));

        // Assert: All runner time records should remain
        final runnerTimeRecords =
            result.where((r) => r.type == RecordType.runnerTime).toList();
        expect(runnerTimeRecords.length, equals(2));
      });

      test('handles records with no duplicates', () {
        // Arrange: Create records without duplicates
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '1.5',
            type: RecordType.confirmRunner,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: '2.0',
            type: RecordType.runnerTime,
            place: 2,
          ),
        ];

        // Act: Clean up (should not change anything)
        final result =
            SimpleConflictResolver.cleanupDuplicateConfirmations(records);

        // Assert: Should return same records
        expect(result.length, equals(records.length));
        expect(result.where((r) => r.type == RecordType.confirmRunner).length,
            equals(1));
        expect(result.where((r) => r.type == RecordType.runnerTime).length,
            equals(2));
      });
    });

    group('Performance Comparison Tests', () {
      test('handles large dataset efficiently', () {
        // Arrange: Create a large dataset
        final records = <TimeRecord>[];
        for (int i = 1; i <= 1000; i++) {
          records.add(createTimeRecord(
            elapsedTime: '$i.0',
            type: RecordType.runnerTime,
            place: i,
          ));

          // Add some conflicts
          if (i % 10 == 0) {
            records.add(createTimeRecord(
              elapsedTime: 'TBD',
              type: RecordType.runnerTime,
              place: i + 1,
              conflict: ConflictDetails(type: RecordType.missingTime),
            ));
          }
        }

        // Act & Assert: Should complete quickly
        final stopwatch = Stopwatch()..start();

        final conflicts = SimpleConflictResolver.identifyConflicts(records);
        final cleanedRecords =
            SimpleConflictResolver.cleanupDuplicateConfirmations(records);

        stopwatch.stop();

        // Should complete in reasonable time (less than 100ms for 1000 records)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(conflicts.length, equals(100)); // 10% of records have conflicts
        expect(cleanedRecords.length,
            equals(records.length)); // No duplicates to remove
      });
    });

    group('Edge Cases', () {
      test('handles empty records list', () {
        // Act & Assert: Should not throw
        expect(() => SimpleConflictResolver.identifyConflicts([]),
            returnsNormally);
        expect(() => SimpleConflictResolver.cleanupDuplicateConfirmations([]),
            returnsNormally);

        final conflicts = SimpleConflictResolver.identifyConflicts([]);
        expect(conflicts, isEmpty);
      });

      test('handles records with null places', () {
        // Arrange: Create records with null places
        final records = [
          createTimeRecord(
            elapsedTime: '1.0',
            type: RecordType.runnerTime,
            place: null, // Null place
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
        ];

        // Act & Assert: Should handle gracefully
        final conflicts = SimpleConflictResolver.identifyConflicts(records);
        expect(conflicts.length, equals(1));
        expect(conflicts[0].place, equals(1)); // Should default to index + 1
      });

      test('handles invalid time formats gracefully', () {
        // Arrange: Create records with various time formats
        final records = [
          createTimeRecord(
            elapsedTime: '',
            type: RecordType.runnerTime,
            place: 1,
          ),
          createTimeRecord(
            elapsedTime: 'invalid',
            type: RecordType.runnerTime,
            place: 2,
          ),
          createTimeRecord(
            elapsedTime: 'TBD',
            type: RecordType.runnerTime,
            place: 3,
            conflict: ConflictDetails(type: RecordType.missingTime),
          ),
        ];

        // Act: Should not throw
        final result = SimpleConflictResolver.resolveMissingTimes(
          timingRecords: records,
          runners: [createRunnerRecord(id: 1, bib: '1', name: 'Runner 1')],
          userTimes: ['3.0'],
          conflictPlace: 3,
        );

        // Assert: Should handle gracefully
        expect(result.length, equals(records.length));
      });
    });
  });
}
