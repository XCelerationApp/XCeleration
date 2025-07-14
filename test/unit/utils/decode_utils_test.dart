import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:xceleration/shared/models/time_record.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';

// Generate mocks
@GenerateMocks([DatabaseHelper])
import 'decode_utils_test.mocks.dart';

// Mock context for UI tests
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  late MockBuildContext mockContext;
  late MockDatabaseHelper mockDatabaseHelper;

  setUp(() {
    mockContext = MockBuildContext();
    mockDatabaseHelper = MockDatabaseHelper();

    // Setup mock database responses
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '101'))
        .thenAnswer((_) async => RunnerRecord(
              raceId: 1,
              bib: '101',
              name: 'John Doe',
              team: 'Team',
              teamAbbreviation: 'T',
              grade: 10,
            ));

    // Mock database to return null for unknown bibs
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '102'))
        .thenAnswer((_) async => Future.value(null as RunnerRecord?));
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '103'))
        .thenAnswer((_) async => Future.value(null as RunnerRecord?));
  });

  group('DecodingUtils', () {
    group('decodeRaceTimesString', () {
      test('should decode simple runner times correctly', () async {
        // Arrange
        final encodedData = '10.5,11.2,12.0';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert
        expect(result.records.length, equals(3));
        expect(result.records[0].elapsedTime, equals('10.5'));
        expect(result.records[1].elapsedTime, equals('11.2'));
        expect(result.records[2].elapsedTime, equals('12.0'));

        expect(result.records[0].type, equals(RecordType.runnerTime));
        expect(result.records[1].type, equals(RecordType.runnerTime));
        expect(result.records[2].type, equals(RecordType.runnerTime));

        expect(result.records[0].place, equals(1));
        expect(result.records[1].place, equals(2));
        expect(result.records[2].place, equals(3));

        expect(result.endTime, equals('12.0'));
      });

      test('should decode conflict records correctly', () async {
        // Arrange
        final encodedData = '10.5,RecordType.missingTime 1 11.2,12.0';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert
        expect(
            result.records.length,
            equals(
                3)); // We expect a missing time conflict to create a new record
        expect(result.endTime, equals('12.0'));
      });

      test('should decode confirm runner records correctly', () async {
        // Arrange
        final encodedData = '10.5,RecordType.confirmRunner 0 11.2,12.0';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert
        expect(result.records.length, equals(3));
        expect(result.records[1].type, equals(RecordType.confirmRunner));
        expect(result.endTime, equals('12.0'));
      });

      test('should handle TBD as a valid runner time', () async {
        // Arrange
        final encodedData = '10.5,TBD,12.0';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert
        expect(result.records.length, equals(3));
        expect(result.records[1].elapsedTime, equals('TBD'));
        expect(result.records[1].type, equals(RecordType.runnerTime));
        expect(result.endTime, equals('12.0'));
      });

      test('should handle empty string', () async {
        // Arrange
        final encodedData = '';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert
        expect(result.records.length, equals(0));
        expect(result.endTime, equals(''));
      });

      test('should handle extra commas in race times', () async {
        // Arrange
        final encodedData = '10.5,,11.2,,12.0,';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert - should skip empty entries but keep valid ones
        expect(result.records.length, equals(3));
        expect(result.records[0].elapsedTime, equals('10.5'));
        expect(result.records[1].elapsedTime, equals('11.2'));
        expect(result.records[2].elapsedTime, equals('12.0'));
      });

      test('should handle various record types in race times', () async {
        // Arrange - mixed record types
        final encodedData =
            '10.5,RecordType.extraTime 1 11.2,RecordType.confirmRunner 1 12.0,13.1';

        // Act
        final result = await decodeRaceTimesString(encodedData);

        // Assert - should parse different record types
        expect(result.records.length, equals(4));
        expect(result.records[0].type, equals(RecordType.runnerTime));
        expect(result.records[1].type, equals(RecordType.extraTime));
        expect(result.records[2].type, equals(RecordType.confirmRunner));
        expect(result.records[3].type, equals(RecordType.runnerTime));
      });

      test('should throw on malformed record type syntax', () async {
        // Arrange - malformed record type
        final encodedData = '10.5,RecordType.invalidType 1 11.2,12.0';

        // Act & Assert
        expect(() => decodeRaceTimesString(encodedData), throwsException);
      });
    });

    // We won't test private helper methods directly, they are tested indirectly through the public API

    group('decodeBibRecordsString', () {
      test('should decode bib numbers correctly and fetch runner data',
          () async {
        // Arrange
        final encodedBibs = '101,102,103';
        final raceId = 1;

        // Act
        final result = await decodeBibRecordsString(
            mockDatabaseHelper, encodedBibs, raceId);

        // Assert - only bib 101 is in our mock database
        expect(result.length, equals(3));
        expect(result[0].bib, equals('101'));
        expect(result[0].name, equals('John Doe'));
        expect(result[1].bib, equals('102'));
        expect(result[1].error, equals('Runner not found'));
        expect(result[2].bib, equals('103'));
        expect(result[2].error, equals('Runner not found'));
      });

      test('should handle empty bib string', () async {
        // Arrange
        final encodedBibs = '';
        final raceId = 1;

        // Act
        final result = await decodeBibRecordsString(
            mockDatabaseHelper, encodedBibs, raceId);

        // Assert
        expect(result.length, equals(0));
      });

      test('should handle malformed bib string with extra commas', () async {
        // Arrange - this has empty entries between commas
        final encodedBibs = '101,,102,,';
        final raceId = 1;

        // Act
        final result = await decodeBibRecordsString(
            mockDatabaseHelper, encodedBibs, raceId);

        // Assert - should skip empty entries
        expect(result.where((r) => r.bib.isNotEmpty).length, equals(2));
      });

      test('should handle whitespace in bib string', () async {
        // Arrange
        final encodedBibs = ' 101, 102 , 103';
        final raceId = 1;

        // Act
        final result = await decodeBibRecordsString(
            mockDatabaseHelper, encodedBibs, raceId);

        // Assert - should trim whitespace and find the bibs
        expect(result.length, equals(3));
      });
    });

    group('decodeEncodedRunners', () {
      test('should decode encoded runners correctly', () async {
        // Arrange
        final encodedRunners =
            'John%20Doe,Team,10th%20Grade,10 Jane%20Smith,Team,11th%20Grade,11';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert
        expect(result, isNotNull);
        expect(result!.length, equals(2));
      });

      test('should handle malformed runner data gracefully', () async {
        // Arrange - missing a field
        final encodedRunners = 'John%20Doe,Team,10';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert - should not add the invalid runner
        expect(result, isNotNull);
        expect(result!.length, equals(0));
      });

      test('should handle empty string', () async {
        // Arrange
        final encodedRunners = '';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert
        expect(result, isNotNull);
        expect(result!.length, equals(0));
      });

      test('should handle runners with special characters in names', () async {
        // Arrange - runner with special characters
        final encodedRunners = '1,John,St.%20Mary%27s,12th%20Grade,12';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert - should decode URL encoded characters correctly
        expect(result, isNotNull);
        expect(result!.length, equals(1));
        expect(result[0].bib, equals('1'));
        expect(result[0].name, equals('John'));
        expect(result[0].team, equals('St. Mary\'s'));
        expect(result[0].grade, equals(12));
      });

      test('should handle malformed URL encoding', () async {
        // Arrange - malformed URL encoding (% followed by invalid hex)
        final encodedRunners = 'Mal%2GFormed,Team,Grade,15';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert - should handle or reject malformed encoding without crashing
        expect(result, isNotNull);
      });

      test('should handle partial or incomplete runner data', () async {
        // Arrange - incomplete runner data with missing field but correct fields count
        final encodedRunners = ',Empty%20Team,11th%20Grade,12';

        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);

        // Assert - should create runner with empty name
        expect(result, isNotNull);
        expect(result!.length, equals(1));
        expect(result[0].name, 'Empty Team');
      });
    });

    group('isValidTimingData', () {
      test('should validate correct timing data', () {
        // Arrange
        final timingData = TimingData(
          records: [
            TimeRecord(
              elapsedTime: '10.5',
              type: RecordType.runnerTime,
              place: 1,
            ),
          ],
          endTime: '10.5',
          startTime: null,
        );

        // Act & Assert
        expect(isValidTimingData(timingData), isTrue);
      });

      test('should invalidate timing data with no records', () {
        // Arrange
        final timingData = TimingData(
          records: [],
          endTime: '10.5',
          startTime: null,
        );

        // Act & Assert
        expect(isValidTimingData(timingData), isFalse);
      });

      test('should invalidate timing data with empty endTime', () {
        // Arrange
        final timingData = TimingData(
          records: [
            TimeRecord(
              elapsedTime: '10.5',
              type: RecordType.runnerTime,
              place: 1,
            ),
          ],
          endTime: '',
          startTime: null,
        );

        // Act & Assert
        expect(isValidTimingData(timingData), isFalse);
      });
    });

    group('isValidBibData', () {
      test('should validate correct runner record', () {
        // Arrange
        final runner = RunnerRecord(
          raceId: 1,
          bib: '101',
          name: 'John Doe',
          grade: 10,
          team: 'Team',
          teamAbbreviation: 'T',
        );

        // Act & Assert
        expect(isValidBibData(runner), isTrue);
      });

      test('should validate runner with "Runner not found" error', () {
        // Arrange
        final runner = RunnerRecord(
          runnerId: -1,
          raceId: -1,
          bib: '101',
          name: 'Unknown',
          grade: 0,
          team: 'Unknown',
          teamAbbreviation: 'N/A',
          error: 'Runner not found',
        );

        // Act & Assert
        expect(isValidBibData(runner), isTrue);
      });

      test('should invalidate runner with empty fields', () {
        // Arrange
        final runner = RunnerRecord(
          raceId: 1,
          bib: '', // Empty bib
          name: 'John Doe',
          grade: 10,
          team: 'Team',
          teamAbbreviation: 'T',
        );

        // Act & Assert
        expect(isValidBibData(runner), isFalse);
      });
    });
  });
}
