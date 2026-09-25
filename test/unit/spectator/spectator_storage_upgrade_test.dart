import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/spectator/services/spectator_storage_service.dart';

// Updating from the store version: a spectator's saved races must still
// open, even if the old version saved one race twice.

void main() {
  sqfliteFfiInit();

  test('upgrades a store database that holds a race twice', () async {
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('spectator_upgrade');
    addTearDown(() => dir.delete(recursive: true));
    await databaseFactory.setDatabasesPath(dir.path);

    // As 1.0.2 made it: version 1, no unique index on race_uuid.
    final old = await databaseFactory.openDatabase(
      p.join(dir.path, 'spectator_races.db'),
      options: OpenDatabaseOptions(version: 1),
    );
    await old.execute('''
      CREATE TABLE IF NOT EXISTS spectator_races (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_uuid TEXT,
        race_name TEXT NOT NULL,
        race_date TEXT,
        location TEXT,
        distance REAL,
        distance_unit TEXT,
        encoded_payload TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        race_data TEXT NOT NULL
      )''');
    for (final (uuid, name) in [
      ('a', 'Invitational (old copy)'),
      ('a', 'Invitational'),
      ('b', 'League Meet'),
      (null, 'No id'),
      (null, 'No id either'),
    ]) {
      await old.insert('spectator_races', {
        'race_uuid': uuid,
        'race_name': name,
        'encoded_payload': '',
        'received_at': 0,
        'race_data': '',
      });
    }
    await old.close();

    final races = await SpectatorStorageService.instance.getAllRaces();

    expect(races.map((r) => r['race_name']),
        unorderedEquals(['Invitational', 'League Meet', 'No id', 'No id either']),
        reason: 'the newest copy of a race is kept, and races without an id '
            'are left alone');
  });
}
