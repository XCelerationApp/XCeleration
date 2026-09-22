import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/xce_peer_name.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

void main() {
  RaceRecord race({int id = 3, String name = 'Varsity Boys', int day = 20}) =>
      RaceRecord(
        raceId: id,
        date: DateTime.utc(2026, 9, day),
        name: name,
        type: 'DeviceName.verifier',
      );

  group('xceRaceKey', () {
    test('is the same on every phone that loaded the same race', () {
      // Each role stores the race under its own type; the key ignores it.
      final onBibPhone = RaceRecord(
        raceId: 3,
        date: DateTime.utc(2026, 9, 20),
        name: 'Varsity Boys',
        type: 'DeviceName.bibRecorderV2',
      );
      expect(xceRaceKey(onBibPhone), xceRaceKey(race()));
      expect(xceRaceKey(race()), hasLength(8));
    });

    test('differs for two coaches whose races share a local id', () {
      expect(xceRaceKey(race(name: 'Varsity Girls')), isNot(xceRaceKey(race())));
      expect(xceRaceKey(race(day: 21)), isNot(xceRaceKey(race())));
    });
  });

  group('advertised name', () {
    test('round-trips role, race key and hostname', () {
      final name =
          buildXceAdvertisedName(Role.fixer, 'a1b2c3d4', hostname: 'Teos-iPhone');

      expect(parseXceDeviceName(name), (Role.fixer, 'a1b2c3d4', 'Teos-iPhone'));
    });

    test('shortens long hostnames to fit the 63-byte Multipeer limit', () {
      final name = buildXceAdvertisedName(Role.bibRecorderV2, 'a1b2c3d4',
          hostname: 'Élodie’s iPhone 17 Pro Max — Cross Country Finish Line');

      expect(utf8.encode(name).length, lessThanOrEqualTo(kMaxAdvertisedNameBytes));
      expect(name, startsWith('xce|BIB|a1b2c3d4|Élodie’s iPhone'));
      // Cut on a character boundary, so the name still decodes cleanly.
      expect(utf8.decode(utf8.encode(name)), name);
    });
  });
}
