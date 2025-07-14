import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/time_record.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';

class ConflictDetailsMock {
  final Map<String, dynamic> data;

  ConflictDetailsMock({required this.data});
}

void main() {
  group('EncodingUtils', () {
    group('encodeTimeRecords', () {
      test('should encode simple runner times correctly', () {
        // Arrange
        final records = [
          TimeRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: false,
          ),
          TimeRecord(
            elapsedTime: '11.2',
            type: RecordType.runnerTime,
            place: 2,
            isConfirmed: false,
          ),
          TimeRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
          ),
        ];

        // Act
        final result = encodeTimeRecords(records);

        // Assert
        expect(result, equals('10.5,11.2,12.0'));
      });

      test('should encode timing records with conflicts correctly', () {
        // Arrange
        final records = [
          TimeRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: false,
          ),
          TimeRecord(
            elapsedTime: '11.2',
            type: RecordType.missingTime,
            place: 2,
            isConfirmed: false,
            conflict: ConflictDetails(
              type: RecordType.missingTime,
              data: {'offBy': 1},
            ),
          ),
          TimeRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
          ),
        ];

        // Act
        final result = encodeTimeRecords(records);

        // Assert
        expect(result, equals('10.5,RecordType.missingTime 1 11.2,12.0'));
      });

      test('should handle null conflicts gracefully', () {
        // Arrange
        final records = [
          TimeRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: false,
          ),
          TimeRecord(
            elapsedTime: '11.2',
            type: RecordType.missingTime,
            place: 2,
            isConfirmed: false,
            conflict: null,
          ),
          TimeRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
          ),
        ];

        // Act
        final result = encodeTimeRecords(records);

        // Assert
        expect(result, equals('10.5,12.0'));
      });

      test('should handle missing offBy in conflict data', () {
        // Arrange
        final records = [
          TimeRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
            isConfirmed: false,
          ),
          TimeRecord(
            elapsedTime: '11.2',
            type: RecordType.missingTime,
            place: 2,
            isConfirmed: false,
            conflict: ConflictDetails(
              type: RecordType.missingTime,
              data: {'someOtherField': 'value'},
            ),
          ),
          TimeRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
            isConfirmed: false,
          ),
        ];

        // Act
        final result = encodeTimeRecords(records);

        // Assert
        expect(result, equals('10.5,12.0'));
      });
    });

    group('encodeBibRecords', () {
      test('should encode bib records correctly', () {
        // Arrange
        final runners = [
          RunnerRecord(
            raceId: 1,
            bib: '101',
            name: 'John Doe',
            grade: 10,
            team: 'Team 1',
            teamAbbreviation: 'T1',
          ),
          RunnerRecord(
            raceId: 1,
            bib: '102',
            name: 'Jane Smith',
            grade: 11,
            team: 'Team 2',
            teamAbbreviation: 'T2',
          ),
        ];

        // Act
        final result = encodeBibRecords(runners);

        // Assert
        expect(result, equals('101,102'));
      });

      test('should handle empty list correctly', () {
        // Arrange
        final runners = <RunnerRecord>[];

        // Act
        final result = encodeBibRecords(runners);

        // Assert
        expect(result, equals(''));
      });
    });

    // Note: Testing getEncodedRunnersData would require more complex DB mocking
    // We'll leave this for a more comprehensive test suite
  });
}
