import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/time_formatter.dart';

void main() {
  group('loadDurationFromString', () {
    Duration? parse(String s) => TimeFormatter.loadDurationFromString(s);

    test('reads the formats the app writes', () {
      expect(parse('12:34.56'),
          const Duration(minutes: 12, seconds: 34, milliseconds: 560));
      expect(parse('1:02:03.4'),
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 400));
      expect(parse('59.05'), const Duration(seconds: 59, milliseconds: 50));
    });

    test('only the first three decimals are milliseconds', () {
      // How a Dart Duration prints: this was read as 560,000 ms.
      expect(parse('0:12:34.560000'),
          const Duration(minutes: 12, seconds: 34, milliseconds: 560));
    });

    test('a formatted time reads back as itself', () {
      const d = Duration(minutes: 17, seconds: 3, milliseconds: 90);
      expect(parse(TimeFormatter.formatDuration(d)), d);
    });

    test('rejects text that is not a time', () {
      expect(parse('TBD'), isNull);
      expect(parse(''), isNull);
      expect(parse('1O:05.0'), isNull);
    });
  });
}
