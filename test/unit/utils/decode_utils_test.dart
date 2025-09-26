import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';

void main() {
  group('TimingDecodeUtils', () {
    group('decodeEncodedTimingData', () {
      test('should decode simple timing data correctly', () async {
        // Arrange - encoded timing data
        final encodedData = '10.5,11.2,12.0';

        // Act
        final result =
            await TimingDecodeUtils.decodeEncodedTimingData(encodedData);

        // Assert
        expect(result.length, equals(3));
        expect(result[0].time, equals('10.5'));
        expect(result[0].hasConflict, isFalse);

        expect(result[1].time, equals('11.2'));
        expect(result[1].hasConflict, isFalse);

        expect(result[2].time, equals('12.0'));
        expect(result[2].hasConflict, isFalse);
      });

      test('should decode timing data with conflicts correctly', () async {
        // Arrange - encoded timing data with conflicts
        final encodedData = '10.5,MT 1 11.2,12.0';

        // Act
        final result =
            await TimingDecodeUtils.decodeEncodedTimingData(encodedData);

        // Assert
        expect(result.length, equals(3));
        expect(result[0].time, equals('10.5'));
        expect(result[0].hasConflict, isFalse);

        expect(result[1].time, equals('11.2'));
        expect(result[1].hasConflict, isTrue);
        expect(result[1].conflict!.type, equals(ConflictType.missingTime));
        expect(result[1].conflict!.offBy, equals(1));

        expect(result[2].time, equals('12.0'));
        expect(result[2].hasConflict, isFalse);
      });

      test('should handle empty string', () async {
        // Arrange
        final encodedData = '';

        // Act
        final result =
            await TimingDecodeUtils.decodeEncodedTimingData(encodedData);

        // Assert
        expect(result.length, equals(0));
      });

      test('should handle malformed data gracefully', () async {
        // Arrange - some malformed data mixed with valid
        final encodedData = '10.5,invalid_data,12.0';

        // Act
        final result =
            await TimingDecodeUtils.decodeEncodedTimingData(encodedData);

        // Assert - should skip invalid data
        expect(result.length, equals(2));
        expect(result[0].time, equals('10.5'));
        expect(result[1].time, equals('12.0'));
      });
    });
  });
}
