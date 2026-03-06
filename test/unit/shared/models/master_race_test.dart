import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

void main() {
  group('MasterRace', () {
    tearDown(() {
      MasterRace.clearAllInstances();
    });

    group('getInstance', () {
      test('returns the same instance for the same race ID', () {
        final a = MasterRace.getInstance(1);
        final b = MasterRace.getInstance(1);

        expect(identical(a, b), isTrue);
      });

      test('returns different instances for different race IDs', () {
        final a = MasterRace.getInstance(1);
        final b = MasterRace.getInstance(2);

        expect(identical(a, b), isFalse);
      });
    });

    group('clearInstance', () {
      test('removes the instance so a fresh one is returned on next get', () {
        final original = MasterRace.getInstance(1);
        MasterRace.clearInstance(1);
        final fresh = MasterRace.getInstance(1);

        expect(identical(original, fresh), isFalse);
      });

      test('is a no-op when called with an unknown race ID', () {
        expect(() => MasterRace.clearInstance(999), returnsNormally);
      });

      test('does not affect instances for other race IDs', () {
        final race2 = MasterRace.getInstance(2);
        MasterRace.getInstance(1);
        MasterRace.clearInstance(1);
        final race2Again = MasterRace.getInstance(2);

        expect(identical(race2, race2Again), isTrue);
      });
    });
  });
}
