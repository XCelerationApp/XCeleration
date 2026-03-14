import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';

void main() {
  group('Conflict', () {
    group('constructor', () {
      test('stores type and offBy', () {
        final conflict = Conflict(type: ConflictType.missingTime, offBy: 3);
        expect(conflict.type, ConflictType.missingTime);
        expect(conflict.offBy, 3);
      });

      test('defaults offBy to 1', () {
        final conflict = Conflict(type: ConflictType.extraTime);
        expect(conflict.offBy, 1);
      });
    });

    group('toString', () {
      test('returns a string containing the type and offBy', () {
        final conflict = Conflict(type: ConflictType.confirmRunner, offBy: 2);
        final result = conflict.toString();
        expect(result, contains('confirmRunner'));
        expect(result, contains('2'));
      });
    });

    group('encode', () {
      test('encodes confirmRunner as index 0', () {
        expect(Conflict(type: ConflictType.confirmRunner, offBy: 1).encode(), '0,1');
      });

      test('encodes missingTime as index 1', () {
        expect(Conflict(type: ConflictType.missingTime, offBy: 3).encode(), '1,3');
      });

      test('encodes extraTime as index 2', () {
        expect(Conflict(type: ConflictType.extraTime, offBy: 5).encode(), '2,5');
      });
    });

    group('decode', () {
      test('reconstructs confirmRunner from index 0', () {
        final conflict = Conflict.decode('0,1');
        expect(conflict.type, ConflictType.confirmRunner);
        expect(conflict.offBy, 1);
      });

      test('reconstructs missingTime from index 1', () {
        final conflict = Conflict.decode('1,3');
        expect(conflict.type, ConflictType.missingTime);
        expect(conflict.offBy, 3);
      });

      test('reconstructs extraTime from index 2', () {
        final conflict = Conflict.decode('2,5');
        expect(conflict.type, ConflictType.extraTime);
        expect(conflict.offBy, 5);
      });
    });

    group('encode / decode round-trip', () {
      for (final type in ConflictType.values) {
        test('round-trips ${type.name}', () {
          final original = Conflict(type: type, offBy: 2);
          final decoded = Conflict.decode(original.encode());
          expect(decoded.type, original.type);
          expect(decoded.offBy, original.offBy);
        });
      }
    });
  });
}
