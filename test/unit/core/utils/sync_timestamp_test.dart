import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/sync_timestamp.dart';

void main() {
  group('SyncTimestamp', () {
    group('now', () {
      test('returns an ISO-8601 string marked as UTC', () {
        expect(SyncTimestamp.now(), endsWith('Z'));
      });

      test('parses back to the current instant', () {
        final parsed = DateTime.parse(SyncTimestamp.now());

        expect(DateTime.now().toUtc().difference(parsed).inSeconds.abs(),
            lessThan(5));
      });
    });
  });
}
