import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/local_schema.dart';
import '../utils/logger.dart';
import 'i_database_connection_provider.dart';

class DatabaseConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;

  @override
  Future<Database> get database async {
    if (_db == null) {
      final db = await _initDB('races.db');
      _db ??= db;
    }
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
    Logger.d('Schema version mismatch ($oldVersion → $newVersion): nuking local DB');
    await db.close();
    final path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _db = await openDatabase(path, version: newVersion, onCreate: _createDB);
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
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
  }

  @override
  Future<void> deleteUserData(String userId) async {
    Logger.d('Deleting local data for user $userId');
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('races', where: 'owner_user_id = ?', whereArgs: [userId]);
      await txn.delete('sync_state');
    });
  }
}
