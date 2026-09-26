import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_suggestions.dart';

// The gaps between times, and where a stray tap most likely is: right on
// top of another time.

void main() {
  test('an extra time stands out under half a second, not in a near tie', () {
    expect(
        likelyExtraTime(['15:00.00', '15:02.24', '15:04.47'],
                start: '14:58.00')!
            .clear,
        isFalse);
    expect(
        likelyExtraTime(['15:00.00', '15:02.00', '15:02.30'],
                start: '14:58.00')!
            .clear,
        isTrue);
  });

  group('likelyExtraTime', () {
    test('points to the second of the two closest times', () {
      final spot = likelyExtraTime(
          ['15:00.00', '15:04.00', '15:04.20', '15:09.00'],
          start: '14:57.00');
      expect(spot!.row, 2);
      expect(spot.gap, const Duration(milliseconds: 200));
    });
  });

  test('gapsBefore gives each time\'s gap from the one before', () {
    expect(gapsBefore(['15:00.00', 'TBD', '15:03.50'], start: '14:59.00'), [
      const Duration(seconds: 1),
      null,
      const Duration(milliseconds: 3500),
    ]);
  });

  test('describeGap says a gap as a coach would', () {
    expect(describeGap(const Duration(milliseconds: 12340)), '12.3 s');
  });
}
