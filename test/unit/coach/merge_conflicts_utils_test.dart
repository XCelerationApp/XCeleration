import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/utils/merge_conflicts_utils.dart';

void main() {
  group('getPreviousValidTimeIndex', () {
    test('returns null when all preceding entries are TBD', () {
      final times = ['TBD', 'TBD', '1:00.0'];
      expect(getPreviousValidTimeIndex(times, 2), isNull);
    });

    test('returns null at index 0 (no preceding entries)', () {
      final times = ['1:00.0', '1:01.0'];
      expect(getPreviousValidTimeIndex(times, 0), isNull);
    });

    test('returns index of nearest non-TBD time before recordIndex', () {
      final times = ['1:00.0', 'TBD', '1:02.0'];
      expect(getPreviousValidTimeIndex(times, 2), equals(0));
    });

    test('skips TBD entries to find previous valid time', () {
      final times = ['1:00.0', 'TBD', 'TBD', '1:03.0'];
      expect(getPreviousValidTimeIndex(times, 3), equals(0));
    });

    test('returns immediately preceding index when no TBDs in between', () {
      final times = ['1:00.0', '1:01.0', '1:02.0'];
      expect(getPreviousValidTimeIndex(times, 2), equals(1));
    });
  });

  group('getNextValidTimeIndex', () {
    test('returns null when all subsequent entries are TBD', () {
      final times = ['1:00.0', 'TBD', 'TBD'];
      expect(getNextValidTimeIndex(times, 0), isNull);
    });

    test('returns null at last index (no subsequent entries)', () {
      final times = ['1:00.0', '1:01.0'];
      expect(getNextValidTimeIndex(times, 1), isNull);
    });

    test('returns index of nearest non-TBD time after recordIndex', () {
      final times = ['1:00.0', 'TBD', '1:02.0'];
      expect(getNextValidTimeIndex(times, 0), equals(2));
    });

    test('skips TBD entries to find next valid time', () {
      final times = ['1:00.0', 'TBD', 'TBD', '1:03.0'];
      expect(getNextValidTimeIndex(times, 0), equals(3));
    });

    test('returns immediately following index when no TBDs in between', () {
      final times = ['1:00.0', '1:01.0', '1:02.0'];
      expect(getNextValidTimeIndex(times, 0), equals(1));
    });
  });

  group('validateTimeInContext', () {
    const endTime = '2:00.0';

    test('returns null for TBD time', () {
      final times = ['1:00.0', 'TBD', '1:30.0'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });

    test('returns null for valid time in correct ascending order', () {
      final times = ['1:00.0', '1:15.0', '1:30.0'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });

    test('returns null for valid time at start with no predecessor', () {
      final times = ['1:00.0', '1:30.0'];
      expect(validateTimeInContext(times, 0, endTime), isNull);
    });

    test('returns null for valid time at end with no successor', () {
      final times = ['1:00.0', '1:30.0'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });

    test('returns null when only non-parseable times are in context', () {
      // currentTime is not parseable → returns null early
      final times = ['1:00.0', 'notavalidtime', '1:30.0'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });

    test('returns error when time duplicates another entry', () {
      final times = ['1:00.0', '1:00.0', '1:30.0'];
      expect(validateTimeInContext(times, 1, endTime), equals('Invalid Time'));
    });

    test('returns error when time is not greater than previous valid time', () {
      final times = ['1:30.0', '1:00.0'];
      expect(validateTimeInContext(times, 1, endTime), equals('Invalid Time'));
    });

    test('returns error when time equals previous valid time', () {
      final times = ['1:00.0', '1:00.0'];
      expect(validateTimeInContext(times, 1, endTime), equals('Invalid Time'));
    });

    test('returns error when time is not less than next valid time', () {
      final times = ['1:30.0', '1:00.0'];
      expect(validateTimeInContext(times, 0, endTime), equals('Invalid Time'));
    });

    test('skips TBD when comparing with previous valid time', () {
      final times = ['1:00.0', 'TBD', '0:59.0'];
      // 0:59.0 is less than 1:00.0 — invalid
      expect(validateTimeInContext(times, 2, endTime), equals('Invalid Time'));
    });

    test('skips TBD when comparing with next valid time', () {
      final times = ['1:30.0', 'TBD', '1:00.0'];
      // 1:30.0 is greater than next valid 1:00.0 — invalid
      expect(validateTimeInContext(times, 0, endTime), equals('Invalid Time'));
    });

    test('returns error when time exceeds endTime', () {
      final times = ['1:00.0', '2:30.0'];
      expect(validateTimeInContext(times, 1, endTime), equals('Invalid Time'));
    });

    test(
        'returns null when time equals endTime (boundary: <= is invalid, > triggers error)',
        () {
      // currentDuration > endDuration triggers error; equal does not
      final times = ['1:00.0', '2:00.0'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });

    test('returns null when all other times are TBD (no ordering constraints)',
        () {
      final times = ['TBD', '1:15.0', 'TBD'];
      expect(validateTimeInContext(times, 1, endTime), isNull);
    });
  });
}
