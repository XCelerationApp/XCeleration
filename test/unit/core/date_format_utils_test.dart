import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/date_format_utils.dart';

/// Builds a [DateTime] that is [days] calendar days from today,
/// using noon local time to stay clear of DST boundaries.
DateTime _daysFromNow(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, 12);
}

void main() {
  group('DateFormatUtils.formatRelativeDate', () {
    test('returns "Today" for today', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(0)), 'Today');
    });

    test('returns "Tomorrow" for one day ahead', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(1)), 'Tomorrow');
    });

    test('returns "Yesterday" for one day ago', () {
      expect(DateFormatUtils.formatRelativeDate(_daysFromNow(-1)), 'Yesterday');
    });

    test('returns "In N days" for 2–7 days ahead', () {
      for (var i = 2; i <= 7; i++) {
        expect(
          DateFormatUtils.formatRelativeDate(_daysFromNow(i)),
          'In $i days',
          reason: 'failed for i=$i',
        );
      }
    });

    test('returns "N days ago" for 2–7 days in the past', () {
      for (var i = 2; i <= 7; i++) {
        expect(
          DateFormatUtils.formatRelativeDate(_daysFromNow(-i)),
          '$i days ago',
          reason: 'failed for i=$i',
        );
      }
    });

    test('returns M/D/YYYY for dates more than 7 days in the future', () {
      final date = DateTime(2030, 6, 15);
      expect(DateFormatUtils.formatRelativeDate(date), '6/15/2030');
    });

    test('returns M/D/YYYY for dates more than 7 days in the past', () {
      final date = DateTime(2020, 1, 5);
      expect(DateFormatUtils.formatRelativeDate(date), '1/5/2020');
    });
  });
}
