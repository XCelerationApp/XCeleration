import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/local_schema.dart';
import '../utils/logger.dart';
import 'i_database_connection_provider.dart';

class DatabaseConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;
  String? _currentUserId;

  @override
  Future<Database> get database async {
    if (_db == null) {
      throw StateError(
        'No user database open. Call openForUser() before accessing the database.',
      );
    }
    return _db!;
  }

  @override
  Future<void> openForUser(String userId) async {
    if (_currentUserId == userId && _db != null) return;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _currentUserId = userId;
    _db = await _initDB('races_$userId.db');
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 20,
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
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final row in tables) {
      await db.execute('DROP TABLE IF EXISTS "${row['name'] as String}"');
    }
    await _createDB(db, newVersion);
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _currentUserId = null;
  }

  @override
  Future<void> deleteDatabase() async {
    Logger.d('Deleting database');
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    if (_currentUserId != null) {
      final path = join(await getDatabasesPath(), 'races_$_currentUserId.db');
      await databaseFactory.deleteDatabase(path);
      _currentUserId = null;
    }
  }

  @override
  Future<void> deleteUserData(String userId) async {
    Logger.d('Deleting local data for user $userId');
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final path = join(await getDatabasesPath(), 'races_$userId.db');
    await databaseFactory.deleteDatabase(path);
    _currentUserId = null;
  }
}
