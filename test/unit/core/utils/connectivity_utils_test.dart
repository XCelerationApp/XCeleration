import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/connectivity_utils.dart';

Future<List<InternetAddress>> _resolves(String _) async =>
    [InternetAddress('142.250.64.46')];

Future<List<InternetAddress>> _empty(String _) async => [];

Future<List<InternetAddress>> _throws(String _) async =>
    throw const SocketException('no route');

void main() {
  group('ConnectivityUtils.isOnline', () {
    test('returns true when lookup resolves with an address', () async {
      final result = await ConnectivityUtils.isOnline(lookupFn: _resolves);
      expect(result, isTrue);
    });

    test('returns false when lookup resolves with an empty list', () async {
      final result = await ConnectivityUtils.isOnline(lookupFn: _empty);
      expect(result, isFalse);
    });

    test('returns false when lookup throws', () async {
      final result = await ConnectivityUtils.isOnline(lookupFn: _throws);
      expect(result, isFalse);
    });

    test('returns false when lookup times out', () async {
      Future<List<InternetAddress>> slow(String _) async {
        await Future.delayed(const Duration(seconds: 10));
        return [InternetAddress('1.1.1.1')];
      }

      final result = await ConnectivityUtils.isOnline(lookupFn: slow);
      expect(result, isFalse);
    });
  });
}
