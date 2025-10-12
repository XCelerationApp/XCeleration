import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:xceleration/core/utils/logger.dart';

/// Storage service for spectator race data
class SpectatorStorageService {
  static final SpectatorStorageService instance =
      SpectatorStorageService._init();
  static Database? _database;

  SpectatorStorageService._init();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'spectator_races.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Spectator races table
        await db.execute('''
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
          )
        ''');
      },
    );
  }

  /// Save a received race
  Future<int> saveRace({
    required String? raceUuid,
    required String raceName,
    required String? raceDate,
    required String? location,
    required double? distance,
    required String? distanceUnit,
    required String encodedPayload,
    required String raceData,
  }) async {
    final db = await database;
    try {
      final existingRace = await getRaceByUuid(raceUuid);
      if (existingRace != null) {
        // Update existing race
        await db.update(
          'spectator_races',
          {
            'race_name': raceName,
            'race_date': raceDate,
            'location': location,
            'distance': distance,
            'distance_unit': distanceUnit,
            'encoded_payload': encodedPayload,
            'received_at': DateTime.now().millisecondsSinceEpoch,
            'race_data': raceData,
          },
          where: 'race_uuid = ?',
          whereArgs: [raceUuid],
        );
        Logger.d('Updated existing race: $raceName');
        return existingRace['id'] as int;
      } else {
        // Insert new race
        final id = await db.insert(
          'spectator_races',
          {
            'race_uuid': raceUuid,
            'race_name': raceName,
            'race_date': raceDate,
            'location': location,
            'distance': distance,
            'distance_unit': distanceUnit,
            'encoded_payload': encodedPayload,
            'received_at': DateTime.now().millisecondsSinceEpoch,
            'race_data': raceData,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        Logger.d('Saved new race: $raceName (id: $id)');
        return id;
      }
    } catch (e) {
      Logger.e('Failed to save race: $e');
      rethrow;
    }
  }

  /// Get all saved races
  Future<List<Map<String, dynamic>>> getAllRaces() async {
    final db = await database;
    try {
      final races = await db.query(
        'spectator_races',
        orderBy: 'received_at DESC',
      );
      return races;
    } catch (e) {
      Logger.e('Failed to get races: $e');
      return [];
    }
  }

  /// Get a race by ID
  Future<Map<String, dynamic>?> getRace(int id) async {
    final db = await database;
    try {
      final races = await db.query(
        'spectator_races',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return races.isNotEmpty ? races.first : null;
    } catch (e) {
      Logger.e('Failed to get race: $e');
      return null;
    }
  }

  /// Get a race by UUID
  Future<Map<String, dynamic>?> getRaceByUuid(String? uuid) async {
    if (uuid == null) return null;
    final db = await database;
    try {
      final races = await db.query(
        'spectator_races',
        where: 'race_uuid = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      return races.isNotEmpty ? races.first : null;
    } catch (e) {
      Logger.e('Failed to get race by UUID: $e');
      return null;
    }
  }

  /// Delete a race
  Future<void> deleteRace(int id) async {
    final db = await database;
    try {
      await db.delete(
        'spectator_races',
        where: 'id = ?',
        whereArgs: [id],
      );
      Logger.d('Deleted race with id: $id');
    } catch (e) {
      Logger.e('Failed to delete race: $e');
      rethrow;
    }
  }

  /// Delete all races
  Future<void> deleteAllRaces() async {
    final db = await database;
    try {
      await db.delete('spectator_races');
      Logger.d('Deleted all races');
    } catch (e) {
      Logger.e('Failed to delete all races: $e');
      rethrow;
    }
  }
}
