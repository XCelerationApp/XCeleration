import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/platform_checker.dart';

void main() {
  group('PlatformChecker', () {
    late PlatformChecker checker;

    setUp(() {
      checker = const PlatformChecker();
    });

    test('implements PlatformCheckerInterface', () {
      expect(checker, isA<PlatformCheckerInterface>());
    });

    test('isAndroid delegates to dart:io Platform', () {
      expect(checker.isAndroid, equals(Platform.isAndroid));
    });

    test('isIOS delegates to dart:io Platform', () {
      expect(checker.isIOS, equals(Platform.isIOS));
    });

    test('isAndroid and isIOS are not both true simultaneously', () {
      expect(checker.isAndroid && checker.isIOS, isFalse);
    });
  });
}
