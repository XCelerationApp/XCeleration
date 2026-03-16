import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQL for a stale race_participants table that predates the UUID columns
/// (schema as it existed before v17 migration).
const String _staleRaceParticipantsSql = '''
CREATE TABLE race_participants (
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  team_id INTEGER NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (race_id, runner_id)
)
''';

const String _teamsSql = '''
CREATE TABLE teams (
  team_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL
)
''';

/// SQL for a stale race_results table that predates the runner_uuid column
/// (schema as it existed before v16 migration).
const String _staleRaceResultsSql = '''
CREATE TABLE race_results (
  result_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  race_id INTEGER NOT NULL,
  runner_id INTEGER NOT NULL,
  place INTEGER,
  finish_time INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT,
  is_dirty INTEGER NOT NULL DEFAULT 0
)
''';

const String _runnersSql = '''
CREATE TABLE runners (
  runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL,
  bib_number TEXT UNIQUE NOT NULL,
  is_dirty INTEGER NOT NULL DEFAULT 0
)
''';

const String _racesSql = '''
CREATE TABLE races (
  race_id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL,
  is_dirty INTEGER NOT NULL DEFAULT 0
)
''';

/// Applies the v16 migration SQL (mirrors _onUpgrade in DatabaseConnectionProvider).
Future<void> _applyV16Migration(Database db) async {
  try {
    await db.execute('ALTER TABLE race_results ADD COLUMN runner_uuid TEXT');
  } catch (_) {}
  try {
    await db.execute('ALTER TABLE race_results ADD COLUMN race_uuid TEXT');
  } catch (_) {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseConnectionProvider v16 migration', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(_runnersSql);
      await db.execute(_racesSql);
      await db.execute(_staleRaceResultsSql);
    });

    tearDown(() async {
      await db.close();
    });

    test('adds runner_uuid column to stale race_results table', () async {
      await _applyV16Migration(db);

      // If column is missing this INSERT throws; its presence means migration worked.
      await db.execute(
        "INSERT INTO race_results (uuid, race_id, runner_id, runner_uuid) VALUES ('r1', 1, 1, 'some-uuid')",
      );

      final rows = await db.query('race_results');
      expect(rows.first['runner_uuid'], equals('some-uuid'));
    });

    test('adds race_uuid column to stale race_results table', () async {
      await _applyV16Migration(db);

      await db.execute(
        "INSERT INTO race_results (uuid, race_id, runner_id, race_uuid) VALUES ('r2', 1, 1, 'race-uuid')",
      );

      final rows = await db.query('race_results');
      expect(rows.first['race_uuid'], equals('race-uuid'));
    });

    test('UPDATE race_results SET runner_uuid succeeds after migration', () async {
      // Seed a runner and a race_result row
      await db.execute(
          "INSERT INTO runners (uuid, name, bib_number) VALUES ('runner-uuid-1', 'Alice', '1')");
      await db.execute(
          "INSERT INTO races (uuid, name) VALUES ('race-uuid-1', 'State Meet')");

      await _applyV16Migration(db);

      await db.execute(
          "INSERT INTO race_results (uuid, race_id, runner_id) VALUES ('res-1', 1, 1)");

      // This is the exact UPDATE that crashes on stale databases.
      final count = await db.rawUpdate('''
        UPDATE race_results
        SET runner_uuid = (SELECT uuid FROM runners WHERE runners.runner_id = race_results.runner_id)
        WHERE runner_uuid IS NULL
      ''');

      expect(count, equals(1));
      final rows = await db.query('race_results');
      expect(rows.first['runner_uuid'], equals('runner-uuid-1'));
    });

    test('migration is idempotent on a DB that already has the columns', () async {
      // First migration
      await _applyV16Migration(db);
      // Second migration should not throw
      await expectLater(_applyV16Migration(db), completes);
    });
  });

  group('DatabaseConnectionProvider v17 migration', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(_runnersSql);
      await db.execute(_racesSql);
      await db.execute(_teamsSql);
      await db.execute(_staleRaceParticipantsSql);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> applyV17Migration(Database db) async {
      for (final column in ['race_uuid', 'runner_uuid', 'team_uuid']) {
        try {
          await db.execute(
              'ALTER TABLE race_participants ADD COLUMN $column TEXT');
        } catch (_) {}
      }
    }

    test('adds race_uuid, runner_uuid, team_uuid to stale race_participants', () async {
      await applyV17Migration(db);

      await db.execute(
        "INSERT INTO race_participants (race_id, runner_id, team_id, race_uuid, runner_uuid, team_uuid) VALUES (1, 1, 1, 'r-uuid', 'ru-uuid', 't-uuid')",
      );

      final rows = await db.query('race_participants');
      expect(rows.first['race_uuid'], equals('r-uuid'));
      expect(rows.first['runner_uuid'], equals('ru-uuid'));
      expect(rows.first['team_uuid'], equals('t-uuid'));
    });

    test('UPDATE race_participants SET race_uuid succeeds after migration', () async {
      await db.execute(
          "INSERT INTO races (uuid, name) VALUES ('race-uuid-1', 'State Meet')");
      await db.execute(
          "INSERT INTO runners (uuid, name, bib_number) VALUES ('runner-uuid-1', 'Alice', '1')");
      await db.execute(
          "INSERT INTO teams (uuid, name) VALUES ('team-uuid-1', 'Team A')");

      await applyV17Migration(db);

      await db.execute(
          'INSERT INTO race_participants (race_id, runner_id, team_id) VALUES (1, 1, 1)');

      final count = await db.rawUpdate('''
        UPDATE race_participants
        SET race_uuid = (SELECT uuid FROM races WHERE races.race_id = race_participants.race_id)
        WHERE race_uuid IS NULL
      ''');

      expect(count, equals(1));
      final rows = await db.query('race_participants');
      expect(rows.first['race_uuid'], equals('race-uuid-1'));
    });

    test('migration is idempotent on a DB that already has the columns', () async {
      await applyV17Migration(db);
      await expectLater(applyV17Migration(db), completes);
    });
  });
}
