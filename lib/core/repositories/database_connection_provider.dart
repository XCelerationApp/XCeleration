import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/database/master_race.dart';
import '../utils/local_schema.dart';
import '../utils/logger.dart';
import 'i_database_connection_provider.dart';

/// Opens the coach's local database, one file per signed-in user.
///
/// A single shared file meant a second coach signing in on the same phone saw
/// the first one's races, and deleting an account left them there.
class DatabaseConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;
  String? _openUserId;

  /// The file every user shared before there was one per user.
  static const legacyFileName = 'races.db';

  static String fileNameFor(String userId) => 'races_$userId.db';

  /// Files SQLite keeps next to a database, named after it.
  static const _sidecarSuffixes = ['-wal', '-shm', '-journal'];

  @override
  Future<Database> get database async {
    final db = _db;
    if (db == null) {
      throw StateError(
        'No database is open. openForUser() must be called when a user signs in.',
      );
    }
    return db;
  }

  /// The open or close in progress. Startup and the Coach button can both
  /// open the database at once, and two overlapping opens would both try to
  /// move the old shared file; each waits for the one before it instead.
  Future<void> _pending = Future.value();

  Future<void> _inTurn(Future<void> Function() action) {
    final run = _pending.then((_) => action());
    _pending = run.catchError((_) {});
    return run;
  }

  @override
  Future<void> openForUser(String userId) =>
      _inTurn(() => _openForUser(userId));

  Future<void> _openForUser(String userId) async {
    if (_openUserId == userId && _db != null) return;
    await _close();
    await _claimLegacyDatabase(userId);
    _db = await _initDB(fileNameFor(userId));
    _openUserId = userId;
  }

  /// Hands the old shared database to [userId] the first time anyone signs in
  /// after the switch to per-user files.
  ///
  /// Without this every coach opens the app to an empty roster, because their
  /// races are in a file nothing reads any more. The signed-in session
  /// survives an app update, so the first user to get here is the one who was
  /// already using the phone; a second account signing in later finds the file
  /// gone and starts from what the server has.
  Future<void> _claimLegacyDatabase(String userId) async {
    final directory = await getDatabasesPath();
    final legacy = join(directory, legacyFileName);
    final mine = join(directory, fileNameFor(userId));
    if (!await databaseFactory.databaseExists(legacy)) return;
    if (await databaseFactory.databaseExists(mine)) return;
    // Moved rather than copied, and with the files SQLite keeps beside it: if
    // the old app was killed mid-session, its newest changes are still in the
    // -wal or -journal file, and a copy of the main file alone loses them.
    for (final suffix in _sidecarSuffixes) {
      final file = File('$legacy$suffix');
      if (await file.exists()) await file.rename('$mine$suffix');
    }
    await File(legacy).rename(mine);
    Logger.d('Moved the shared database to $userId');
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 19,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    for (final stmt in splitSqlStatements(localSchemaSql)) {
      await db.execute(stmt);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE races ADD COLUMN owner_user_id TEXT');
        Logger.d('Added owner_user_id column to races table');
      } catch (e) {
        Logger.d('owner_user_id column might already exist: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        Logger.d('Created sync_state table');
      } catch (e) {
        Logger.d('sync_state table might already exist: $e');
      }
    }

    if (oldVersion < 16) {
      try {
        await db
            .execute('ALTER TABLE race_results ADD COLUMN runner_uuid TEXT');
        Logger.d('Added runner_uuid column to race_results table');
      } catch (e) {
        Logger.d('runner_uuid column might already exist in race_results: $e');
      }

      try {
        await db.execute('ALTER TABLE race_results ADD COLUMN race_uuid TEXT');
        Logger.d('Added race_uuid column to race_results table');
      } catch (e) {
        Logger.d('race_uuid column might already exist in race_results: $e');
      }
    }

    if (oldVersion < 17) {
      for (final column in ['race_uuid', 'runner_uuid', 'team_uuid']) {
        try {
          await db.execute(
              'ALTER TABLE race_participants ADD COLUMN $column TEXT');
          Logger.d('Added $column column to race_participants table');
        } catch (e) {
          Logger.d('$column column might already exist in race_participants: $e');
        }
      }
    }

    if (oldVersion < 18) {
      // A deleted row is kept so its deletion can be pushed, but it still held
      // the bib number, team name or place, which blocked the value being used
      // again. SQLite cannot drop a table constraint, so these three tables are
      // rebuilt without theirs and the uniqueness moves to partial indexes that
      // ignore deleted rows.
      for (final table in ['runners', 'teams', 'race_results']) {
        await _rebuildTable(db, table);
      }
      for (final stmt in createIndexStatements()) {
        await db.execute(stmt);
      }
    }

    if (oldVersion < 19) {
      // Which runners are on which team, and which teams are in which race,
      // only ever lived on one phone. Syncing them needs the parents named by
      // uuid, since a local integer id means nothing on another device.
      const columns = {
        'team_rosters': ['team_uuid', 'runner_uuid'],
        'race_team_participation': ['race_uuid', 'team_uuid'],
      };
      for (final entry in columns.entries) {
        for (final column in entry.value) {
          try {
            await db
                .execute('ALTER TABLE ${entry.key} ADD COLUMN $column TEXT');
            Logger.d('Added $column column to ${entry.key}');
          } catch (e) {
            Logger.d('$column might already exist in ${entry.key}: $e');
          }
        }
        // These rows were written before either table synced, so none of them
        // is marked dirty and the roster already on this phone would never be
        // uploaded. Mark them once so the next sync carries them up.
        final marked = await db.rawUpdate(
            'UPDATE ${entry.key} SET is_dirty = 1 WHERE deleted_at IS NULL');
        Logger.d('Marked $marked ${entry.key} rows for their first upload');
      }
    }
  }

  /// Rebuilds [table] to match [localSchemaSql], keeping every row.
  ///
  /// Foreign keys are off (sqflite does not enable them), so dropping the old
  /// table while other tables name it in a REFERENCES clause is safe; the
  /// rename puts the name back.
  Future<void> _rebuildTable(Database db, String table) async {
    final temporary = '${table}__rebuild';
    await db.execute('DROP TABLE IF EXISTS $temporary');
    await db.execute(createTableStatement(table)
        .replaceFirst('IF NOT EXISTS $table', 'IF NOT EXISTS $temporary'));

    Future<Set<String>> columnsOf(String name) async =>
        (await db.rawQuery('PRAGMA table_info($name)'))
            .map((row) => row['name'] as String)
            .toSet();
    final existing = await columnsOf(table);
    final wanted = await columnsOf(temporary);
    final shared =
        wanted.where(existing.contains).map((c) => '"$c"').join(', ');

    await db
        .execute('INSERT INTO $temporary ($shared) SELECT $shared FROM $table');
    await db.execute('DROP TABLE $table');
    await db.execute('ALTER TABLE $temporary RENAME TO $table');
    Logger.d('Rebuilt $table for schema v18');
  }

  @override
  Future<void> close() => _inTurn(_close);

  Future<void> _close() async {
    // Races held in memory belong to this database. Race numbers start at 1
    // in every user's file, so the next user's race 1 would otherwise open
    // with this one's runners and results.
    MasterRace.clearAllInstances();
    await _db?.close();
    _db = null;
    _openUserId = null;
  }

  @override
  Future<void> deleteDatabase() => _inTurn(() async {
        final userId = _openUserId;
        await _close();
        if (userId == null) return;
        Logger.d('Deleting database');
        await databaseFactory.deleteDatabase(
            join(await getDatabasesPath(), fileNameFor(userId)));
      });

  @override
  Future<void> deleteUserData(String userId) => _inTurn(() async {
        if (_openUserId == userId) await _close();
        Logger.d('Deleting local data for a user');
        await databaseFactory.deleteDatabase(
            join(await getDatabasesPath(), fileNameFor(userId)));
      });
}
