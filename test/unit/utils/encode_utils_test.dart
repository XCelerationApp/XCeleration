import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/utils/encode_utils.dart';
import 'package:xceleration/utils/enums.dart';

class ConflictDetailsMock {
  final Map<String, dynamic> data;
  
  ConflictDetailsMock({required this.data});
}

void main() {
  group('EncodingUtils', () {
    group('encodeTimingRecords', () {
      test('should encode simple runner times correctly', () {
        // Arrange
        final records = [
          TimingRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
          ),
          TimingRecord(
            elapsedTime: '11.2',
            type: RecordType.runnerTime,
            place: 2,
          ),
          TimingRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
          ),
        ];
        
        // Act
        final result = encodeTimingRecords(records);
        
        // Assert
        expect(result, equals('10.5,11.2,12.0'));
      });
      
      test('should encode timing records with conflicts correctly', () {
        // Arrange
        final records = [
          TimingRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
          ),
          TimingRecord(
            elapsedTime: '11.2',
            type: RecordType.missingRunner,
            place: 2,
            conflict: ConflictDetails(
              type: RecordType.missingRunner,
              data: {'offBy': 1},
            ),
          ),
          TimingRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
          ),
        ];
        
        // Act
        final result = encodeTimingRecords(records);
        
        // Assert
        expect(result, equals('10.5,RecordType.missingRunner 1 11.2,12.0'));
      });
      
      test('should handle null conflicts gracefully', () {
        // Arrange
        final records = [
          TimingRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
          ),
          TimingRecord(
            elapsedTime: '11.2',
            type: RecordType.missingRunner,
            place: 2,
            conflict: null,
          ),
          TimingRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
          ),
        ];
        
        // Act
        final result = encodeTimingRecords(records);
        
        // Assert
        expect(result, equals('10.5,12.0'));
      });
      
      test('should handle missing offBy in conflict data', () {
        // Arrange
        final records = [
          TimingRecord(
            elapsedTime: '10.5',
            type: RecordType.runnerTime,
            place: 1,
          ),
          TimingRecord(
            elapsedTime: '11.2',
            type: RecordType.missingRunner,
            place: 2,
            conflict: ConflictDetails(
              type: RecordType.missingRunner,
              data: {'someOtherField': 'value'},
            ),
          ),
          TimingRecord(
            elapsedTime: '12.0',
            type: RecordType.runnerTime,
            place: 3,
          ),
        ];
        
        // Act
        final result = encodeTimingRecords(records);
        
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
            school: 'High School',
          ),
          RunnerRecord(
            raceId: 1,
            bib: '102',
            name: 'Jane Smith',
            grade: 11,
            school: 'Another High School',
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
