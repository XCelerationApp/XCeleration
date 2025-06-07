import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/database_helper.dart';
import 'package:xceleration/utils/decode_utils.dart';
import 'package:xceleration/utils/enums.dart';

// Generate mocks
@GenerateMocks([DatabaseHelper])
import 'decode_utils_test.mocks.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  late MockBuildContext mockContext;
  late MockDatabaseHelper mockDatabaseHelper;
  
  setUp(() {
    mockContext = MockBuildContext();
    mockDatabaseHelper = MockDatabaseHelper();
    
    // Setup mock database responses
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '101')).thenAnswer((_) async =>
        RunnerRecord(
          raceId: 1,
          bib: '101',
          name: 'John Doe',
          school: 'Test School',
          grade: 10,
        ));
    
    // Mock database to return null for unknown bibs
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '102')).thenAnswer((_) async => Future.value(null as RunnerRecord?));
    when(mockDatabaseHelper.getRaceRunnerByBib(1, '103')).thenAnswer((_) async => Future.value(null as RunnerRecord?));
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
        final encodedData = '10.5,RecordType.missingRunner 1 11.2,12.0';
        
        // Act
        final result = await decodeRaceTimesString(encodedData);
        
        // Assert
        expect(result.records.length, equals(3));  // We expect a missing runner conflict to create a new record
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
    });
    
    // We won't test private helper methods directly, they are tested indirectly through the public API
    
    group('decodeBibRecordsString', () {
      test('should decode bib numbers correctly and fetch runner data', () async {
        // Arrange
        final encodedBibs = '101,102,103';
        final raceId = 1;
        
        // Act
        final result = await decodeBibRecordsString(mockDatabaseHelper, encodedBibs, raceId);
        
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
        final result = await decodeBibRecordsString(mockDatabaseHelper, encodedBibs, raceId);
        
        // Assert
        expect(result.length, equals(0));
      });
    });
    
    group('decodeEncodedRunners', () {
      test('should decode encoded runners correctly', () async {
        // Arrange
        final encodedRunners = 'John%20Doe,High%20School,10th%20Grade,10 Jane%20Smith,Another%20High%20School,11th%20Grade,11';
        
        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.length, equals(2));
      });
      
      test('should handle malformed runner data gracefully', () async {
        // Arrange - missing a field
        final encodedRunners = 'John%20Doe,High%20School,10';
        
        // Act
        final result = await decodeEncodedRunners(encodedRunners, mockContext);
        
        // Assert - should not add the invalid runner
        expect(result, isNotNull);
        expect(result!.length, equals(0));
      });
    });
    
    group('isValidTimingData', () {
      test('should validate correct timing data', () {
        // Arrange
        final timingData = TimingData(
          records: [
            TimingRecord(
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
            TimingRecord(
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
          school: 'High School',
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
          school: 'Unknown',
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
          school: 'High School',
        );
        
        // Act & Assert
        expect(isValidBibData(runner), isFalse);
      });
    });
  });
}
