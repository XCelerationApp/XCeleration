import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xceleration/core/repositories/database_connection_provider.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

// Upgrading a database that already has races in it. These run the real
// provider against a real file, because an upgrade that goes wrong does so
// on a phone that already holds a season of data.

/// The shape of the tables before v18: uniqueness as table constraints, which
/// a deleted row went on occupying.
const _v17Tables = [
  '''
CREATE TABLE runners (
  runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL CHECK(length(name) > 0),
  grade INTEGER CHECK(grade >= 9 AND grade <= 12),
  bib_number TEXT UNIQUE NOT NULL CHECK(length(bib_number) > 0),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE teams (
  team_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL CHECK(length(name) > 0),
  abbreviation TEXT CHECK(length(abbreviation) <= 3),
  color INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  UNIQUE (name)
)''',
  '''
CREATE TABLE races (
  race_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  owner_user_id TEXT,
  name TEXT NOT NULL CHECK(length(name) > 0),
  race_date TEXT DEFAULT '',
  location TEXT DEFAULT '',
  distance REAL DEFAULT 0,
  distance_unit TEXT DEFAULT 'mi',
  flow_state TEXT DEFAULT 'setup',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE race_results (
  result_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  runner_uuid TEXT,
  race_uuid TEXT,
  team_id INTEGER,
  place INTEGER,
  finish_time INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (race_id) REFERENCES races(race_id) ON DELETE CASCADE,
  FOREIGN KEY (runner_id) REFERENCES runners(runner_id) ON DELETE CASCADE,
  UNIQUE (race_id, runner_id),
  UNIQUE (race_id, place)
)''',
  '''
CREATE TABLE race_participants (
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  team_id INTEGER NOT NULL,
  race_uuid TEXT,
  runner_uuid TEXT,
  team_uuid TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (race_id, runner_id)
)''',
  '''
CREATE TABLE team_rosters (
  team_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  joined_date TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (team_id, runner_id)
)''',
  '''
CREATE TABLE race_team_participation (
  race_id INTEGER NOT NULL,
  team_id INTEGER NOT NULL,
  team_color_override INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (race_id, team_id)
)''',
  '''
CREATE TABLE sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''',
];

const _userId = 'user-abc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory dir;
  late DatabaseConnectionProvider provider;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('xceleration_upgrade');
    await databaseFactory.setDatabasesPath(dir.path);
    provider = DatabaseConnectionProvider();
  });

  tearDown(() async {
    await provider.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Writes a database in the pre-v18 shape, with one season's worth of rows.
  Future<void> seedOldDatabase() async {
    final db = await databaseFactory.openDatabase(
      p.join(dir.path, 'races.db'),
      options: OpenDatabaseOptions(version: 17),
    );
    for (final stmt in _v17Tables) {
      await db.execute(stmt);
    }
    await db.insert('runners',
        {'runner_id': 1, 'name': 'Alice', 'grade': 10, 'bib_number': '101'});
    await db.insert('teams', {'team_id': 1, 'name': 'Eagles', 'color': 0});
    await db.insert('races', {'race_id': 1, 'name': 'Invitational'});
    await db.insert('race_results',
        {'race_id': 1, 'runner_id': 1, 'place': 1, 'finish_time': 900000});
    await db.insert(
        'race_participants', {'race_id': 1, 'runner_id': 1, 'team_id': 1});
    await db.insert('team_rosters', {'team_id': 1, 'runner_id': 1});
    await db
        .insert('race_team_participation', {'race_id': 1, 'team_id': 1});
    await db.close();
  }

  group('one database per user', () {
    test('hands the old shared database to whoever signs in first', () async {
      await seedOldDatabase();

      await provider.openForUser(_userId);
      final db = await provider.database;

      expect((await db.query('runners')).single['name'], 'Alice',
          reason: 'a coach must not open the app to an empty roster');
      expect(File(p.join(dir.path, 'races.db')).existsSync(), isFalse,
          reason: 'the shared file is gone once it has an owner');
      expect(File(p.join(dir.path, 'races_$_userId.db')).existsSync(), isTrue);
    });

    test('keeps changes still in the log when the old app was killed',
        () async {
      // The old app writes in WAL mode and is killed before its log is merged
      // into the main file: the newest rows exist only in races.db-wal.
      final staging = await Directory.systemTemp.createTemp('xceleration_wal');
      addTearDown(() => staging.deleteSync(recursive: true));
      final old = await databaseFactory.openDatabase(
          p.join(staging.path, 'races.db'),
          options: OpenDatabaseOptions(version: 17));
      await old.rawQuery('PRAGMA journal_mode=WAL');
      await old.rawQuery('PRAGMA wal_autocheckpoint=0');
      for (final stmt in _v17Tables) {
        await old.execute(stmt);
      }
      await old.insert('runners',
          {'runner_id': 1, 'name': 'Alice', 'grade': 10, 'bib_number': '101'});
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File(p.join(staging.path, 'races.db$suffix'));
        if (file.existsSync()) file.copySync(p.join(dir.path, 'races.db$suffix'));
      }
      await old.close();

      await provider.openForUser(_userId);

      expect((await (await provider.database).query('runners')).single['name'],
          'Alice');
      for (final suffix in ['', '-wal', '-shm']) {
        expect(File(p.join(dir.path, 'races.db$suffix')).existsSync(), isFalse);
      }
    });

    test('opening twice at once still hands the old database over', () async {
      // Startup and the Coach button both open the signed-in user's database,
      // and on the first launch after the update they can overlap.
      await seedOldDatabase();

      await Future.wait(
          [provider.openForUser(_userId), provider.openForUser(_userId)]);

      expect((await (await provider.database).query('runners')).single['name'],
          'Alice');
    });

    test('forgets the races it had loaded when another account signs in',
        () async {
      // Race numbers start at 1 in every account's database, so a race kept
      // in memory from the last account would open in place of this one's.
      await provider.openForUser(_userId);
      final theirs = MasterRace.getInstance(1);

      await provider.openForUser('someone-else');

      expect(MasterRace.getInstance(1), isNot(same(theirs)));
    });

    test('a second account starts empty rather than seeing the first one\'s races',
        () async {
      await seedOldDatabase();
      await provider.openForUser(_userId);
      expect((await (await provider.database).query('runners')), hasLength(1));

      await provider.openForUser('someone-else');

      expect(await (await provider.database).query('runners'), isEmpty,
          reason: 'one coach must not see another coach\'s runners');
    });

    test('keeps each user on their own file across reopens', () async {
      await provider.openForUser(_userId);
      await (await provider.database).insert(
          'runners', {'name': 'Alice', 'grade': 10, 'bib_number': '101'});

      await provider.openForUser('someone-else');
      await (await provider.database).insert(
          'runners', {'name': 'Bob', 'grade': 11, 'bib_number': '101'});

      await provider.openForUser(_userId);
      expect((await (await provider.database).query('runners')).single['name'],
          'Alice');
    });

    test('refuses to hand out a database before anyone has signed in', () {
      expect(() => provider.database, throwsStateError);
    });

    test('deleting a user\'s data leaves nothing on the phone', () async {
      await provider.openForUser(_userId);
      await (await provider.database).insert(
          'runners', {'name': 'Alice', 'grade': 10, 'bib_number': '101'});

      await provider.deleteUserData(_userId);

      expect(File(p.join(dir.path, 'races_$_userId.db')).existsSync(), isFalse);
    });
  });

  test('keeps every row when upgrading an existing database', () async {
    await seedOldDatabase();

    await provider.openForUser(_userId);
    final db = await provider.database;

    expect((await db.query('runners')).single['name'], 'Alice');
    expect((await db.query('teams')).single['name'], 'Eagles');
    expect((await db.query('races')).single['name'], 'Invitational');
    expect((await db.query('race_results')).single['finish_time'], 900000);
    expect((await db.query('race_participants')), hasLength(1),
        reason: 'tables that were not rebuilt must be untouched');
  });

  test('frees a deleted runner\'s bib number after the upgrade', () async {
    await seedOldDatabase();
    await provider.openForUser(_userId);
    final db = await provider.database;

    await db.update('runners', {'deleted_at': '2026-01-01T00:00:00Z'},
        where: 'runner_id = ?', whereArgs: [1]);

    // Before v18 this threw: the deleted row still held bib 101.
    await db.insert(
        'runners', {'name': 'Bob', 'grade': 11, 'bib_number': '101'});

    final live =
        await db.query('runners', where: 'deleted_at IS NULL');
    expect(live, hasLength(1));
    expect(live.single['name'], 'Bob');
  });

  test('still refuses two live runners with the same bib', () async {
    await seedOldDatabase();
    await provider.openForUser(_userId);
    final db = await provider.database;

    await expectLater(
      db.insert(
          'runners', {'name': 'Bob', 'grade': 11, 'bib_number': '101'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('frees a deleted team\'s name after the upgrade', () async {
    await seedOldDatabase();
    await provider.openForUser(_userId);
    final db = await provider.database;

    await db.update('teams', {'deleted_at': '2026-01-01T00:00:00Z'},
        where: 'team_id = ?', whereArgs: [1]);
    await db.insert('teams', {'name': 'Eagles', 'color': 0});

    expect(await db.query('teams', where: 'deleted_at IS NULL'), hasLength(1));
  });

  test('frees a deleted result\'s place after the upgrade', () async {
    await seedOldDatabase();
    await provider.openForUser(_userId);
    final db = await provider.database;

    await db.update('race_results', {'deleted_at': '2026-01-01T00:00:00Z'},
        where: 'race_id = ?', whereArgs: [1]);
    await db.insert('race_results',
        {'race_id': 1, 'runner_id': 2, 'place': 1, 'finish_time': 900500});

    expect(await db.query('race_results', where: 'deleted_at IS NULL'),
        hasLength(1));
  });

  test('marks the roster already on the phone for its first upload', () async {
    await seedOldDatabase();
    await provider.openForUser(_userId);
    final db = await provider.database;

    // The roster predates either table syncing, so nothing was ever marked.
    final roster = (await db.query('team_rosters')).single;
    expect(roster['is_dirty'], 1,
        reason: 'otherwise the roster on this phone never reaches the server');
    expect(roster.containsKey('team_uuid'), isTrue);
    expect(roster.containsKey('runner_uuid'), isTrue);

    final inRace = (await db.query('race_team_participation')).single;
    expect(inRace['is_dirty'], 1);
  });

  test('a fresh install gets the same uniqueness as an upgraded one',
      () async {
    await provider.openForUser(_userId);
    final db = await provider.database;

    await db.insert(
        'runners', {'name': 'Alice', 'grade': 10, 'bib_number': '101'});
    await db.update('runners', {'deleted_at': '2026-01-01T00:00:00Z'},
        where: 'bib_number = ?', whereArgs: ['101']);
    await db.insert(
        'runners', {'name': 'Bob', 'grade': 11, 'bib_number': '101'});

    expect(await db.query('runners', where: 'deleted_at IS NULL'),
        hasLength(1));
    await expectLater(
      db.insert(
          'runners', {'name': 'Cara', 'grade': 12, 'bib_number': '101'}),
      throwsA(isA<DatabaseException>()),
    );
  });
}
