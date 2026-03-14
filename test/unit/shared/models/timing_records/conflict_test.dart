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
      test('includes the offBy value in the encoded string', () {
        final conflict = Conflict(type: ConflictType.missingTime, offBy: 4);
        expect(conflict.encode(), contains('4'));
      });

      test('produces different output for different conflict types', () {
        final a = Conflict(type: ConflictType.missingTime).encode();
        final b = Conflict(type: ConflictType.extraTime).encode();
        final c = Conflict(type: ConflictType.confirmRunner).encode();
        expect(a, isNot(equals(b)));
        expect(b, isNot(equals(c)));
        expect(a, isNot(equals(c)));
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
  });
}
