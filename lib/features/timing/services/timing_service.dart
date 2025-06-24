import '../../../utils/database_helper.dart';
import '../../../core/utils/logger.dart';
import '../models/timing_record.dart';
import '../models/bib_record.dart';

/// Service for managing timing data persistence and operations
class TimingService {
  final DatabaseHelper _databaseHelper;

  TimingService({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Save a timing record to the database
  Future<void> saveTimingRecord(TimingRecord record) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert('timing_records', record.toJson());
      Logger.d('Saved timing record: ${record.elapsedTime}');
    } catch (e) {
      Logger.e('Error saving timing record', error: e);
      rethrow;
    }
  }

  /// Update an existing timing record
  Future<void> updateTimingRecord(TimingRecord record) async {
    try {
      if (record.id == null) {
        throw Exception('Cannot update record without ID');
      }

      final db = await _databaseHelper.database;
      await db.update(
        'timing_records',
        record.toJson(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      Logger.d('Updated timing record: ${record.id}');
    } catch (e) {
      Logger.e('Error updating timing record', error: e);
      rethrow;
    }
  }

  /// Get all timing records
  Future<List<TimingRecord>> getTimingRecords() async {
    try {
      final db = await _databaseHelper.database;

      // Create table if it doesn't exist
      await _createTimingTablesIfNeeded(db);

      final maps = await db.query(
        'timing_records',
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => TimingRecord.fromJson(map)).toList();
    } catch (e) {
      Logger.e('Error getting timing records', error: e);
      return [];
    }
  }

  /// Save a bib record to the database
  Future<void> saveBibRecord(BibRecord record) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert('bib_records', record.toJson());
      Logger.d('Saved bib record: ${record.bibNumber}');
    } catch (e) {
      Logger.e('Error saving bib record', error: e);
      rethrow;
    }
  }

  /// Get all bib records
  Future<List<BibRecord>> getBibRecords() async {
    try {
      final db = await _databaseHelper.database;

      // Create table if it doesn't exist
      await _createTimingTablesIfNeeded(db);

      final maps = await db.query(
        'bib_records',
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => BibRecord.fromJson(map)).toList();
    } catch (e) {
      Logger.e('Error getting bib records', error: e);
      return [];
    }
  }

  /// Clear all timing and bib records
  Future<void> clearAllRecords() async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        await txn.delete('timing_records');
        await txn.delete('bib_records');
      });
      Logger.d('Cleared all timing records');
    } catch (e) {
      Logger.e('Error clearing timing records', error: e);
      rethrow;
    }
  }

  /// Create timing tables if they don't exist
  Future<void> _createTimingTablesIfNeeded(dynamic db) async {
    try {
      // Create timing_records table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS timing_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          elapsed_time TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          bib_number TEXT,
          runner_name TEXT,
          place INTEGER,
          is_confirmed INTEGER DEFAULT 0,
          metadata TEXT
        )
      ''');

      // Create bib_records table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bib_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bib_number TEXT NOT NULL,
          confidences TEXT,
          name TEXT,
          school TEXT,
          flags TEXT,
          timestamp TEXT,
          is_validated INTEGER DEFAULT 0
        )
      ''');

      Logger.d('Timing tables created/verified');
    } catch (e) {
      Logger.e('Error creating timing tables', error: e);
      rethrow;
    }
  }

  /// Get timing records for a specific race
  Future<List<TimingRecord>> getTimingRecordsForRace(int raceId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'timing_records',
        where: 'race_id = ?',
        whereArgs: [raceId],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => TimingRecord.fromJson(map)).toList();
    } catch (e) {
      Logger.e('Error getting timing records for race', error: e);
      return [];
    }
  }

  /// Associate timing records with a race
  Future<void> associateRecordsWithRace(
      int raceId, List<TimingRecord> records) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final record in records) {
          final updatedRecord = record.copyWith(
            metadata: {...(record.metadata ?? {}), 'race_id': raceId},
          );

          if (record.id != null) {
            await txn.update(
              'timing_records',
              updatedRecord.toJson(),
              where: 'id = ?',
              whereArgs: [record.id],
            );
          }
        }
      });

      Logger.d('Associated ${records.length} records with race $raceId');
    } catch (e) {
      Logger.e('Error associating records with race', error: e);
      rethrow;
    }
  }
}
