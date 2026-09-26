import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_suggestions.dart';

// Where a timing conflict most likely is: a missed runner in the biggest gap
// between times, a stray tap right on top of another time.

void main() {
  group('likelyMissingSpot', () {
    test('points to the biggest gap between times', () {
      final spot = likelyMissingSpot(
        ['15:00.00', '15:02.00', '15:14.00', '15:16.00', 'TBD'],
        start: '14:58.00',
        end: '15:18.00',
      );
      expect(spot!.row, 2, reason: 'the runner came before 15:14.00');
      expect(spot.gap, const Duration(seconds: 12));
    });

    test('can point past the last time, before the count check', () {
      final spot = likelyMissingSpot(['15:00.00', '15:01.00', 'TBD'],
          start: '14:59.00', end: '15:20.00');
      expect(spot!.row, 3);
    });

    test('can point before the first time', () {
      final spot = likelyMissingSpot(['15:30.00', '15:31.00', 'TBD'],
          start: '15:00.00', end: '15:32.00');
      expect(spot!.row, 0);
    });

    test('ignores slots without a time, wherever they are', () {
      final spot = likelyMissingSpot(
          ['15:00.00', 'TBD', '15:01.00', '15:10.00'],
          end: '15:11.00');
      expect(spot!.row, 3);
    });
  });

  test('says when no gap stands out', () {
    final spot = likelyMissingSpot(['15:00.00', '15:05.00', '15:10.50', 'TBD'],
        start: '14:55.00', end: '15:15.00');
    expect(spot!.clear, isFalse, reason: 'every gap is about 5 s');
    expect(
        likelyMissingSpot(['15:00.00', '15:02.00', '15:14.00'],
                start: '14:58.00', end: '15:16.00')!
            .clear,
        isTrue);
  });

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

  test('midpointTime splits a gap', () {
    expect(midpointTime('15:00.00', '15:10.00'), isNotNull);
    expect(midpointTime('15:10.00', '15:00.00'), isNull);
    expect(describeGap(const Duration(milliseconds: 12340)), '12.3 s');
  });
}
