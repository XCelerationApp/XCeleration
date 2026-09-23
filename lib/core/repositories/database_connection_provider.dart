import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/local_schema.dart';
import '../utils/logger.dart';
import 'i_database_connection_provider.dart';

class DatabaseConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;

  @override
  Future<Database> get database async {
    _db ??= await _initDB('races.db');
    return _db!;
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
        await db.execute(
            'ALTER TABLE race_results ADD COLUMN runner_uuid TEXT');
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
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }

  @override
  Future<void> deleteDatabase() async {
    Logger.d('Deleting database');
    final path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _db = null;
  }
}
