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
      version: 15,
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
