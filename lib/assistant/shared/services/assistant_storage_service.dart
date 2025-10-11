import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/race_record.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../models/bib_record.dart';
import '../models/runner.dart';

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => message;
}

/// Shared storage service for assistant mode features (race timing and bib recording)
class AssistantStorageService {
  static final AssistantStorageService instance =
      AssistantStorageService._init();
  static Database? _database;

  AssistantStorageService._init();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'assistant_data.db');

    deleteDatabase(path);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Race history table with composite primary key (race_id, type)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS race_history (
            race_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            date INTEGER NOT NULL,
            name TEXT NOT NULL,
            started_at INTEGER,
            stopped BOOLEAN,
            duration INTEGER,
            PRIMARY KEY (race_id, type)
          )
        ''');

        // Chunks table with composite primary key (race_id, chunk_id)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS timing_chunks (
            race_id INTEGER NOT NULL,
            chunk_id INTEGER NOT NULL,
            timing_data TEXT,
            conflict_record TEXT,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (race_id, chunk_id),
            FOREIGN KEY (race_id) REFERENCES race_history(race_id) ON DELETE CASCADE
          )
        ''');

        // Runners table to store runner data for each race
        await db.execute('''
          CREATE TABLE IF NOT EXISTS runners (
            race_id INTEGER NOT NULL,
            bib_number TEXT NOT NULL,
            name TEXT,
            team_abbreviation TEXT,
            grade TEXT,
            team_color INTEGER,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (race_id, bib_number),
            FOREIGN KEY (race_id) REFERENCES race_history(race_id) ON DELETE CASCADE
          )
        ''');

        // Bib records table with simplified schema - only tracks race_id, bib_number, bib_id
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bib_records (
            race_id INTEGER NOT NULL,
            bib_id INTEGER NOT NULL,
            bib_number TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (race_id, bib_id),
            FOREIGN KEY (race_id) REFERENCES race_history(race_id) ON DELETE CASCADE,
            FOREIGN KEY (race_id, bib_number) REFERENCES runners(race_id, bib_number) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // Race Methods
  Future<void> saveNewRace(RaceRecord race) async {
    if (await getRace(race.raceId, race.type) != null) {
      Logger.e(
          'Race already exists in database: ${race.raceId} (${race.type})');
      throw DatabaseException('Race already loaded');
    }
    final db = await database;
    try {
      await db.insert(
        'race_history',
        race.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.e('Failed to save new race: $e');
      throw DatabaseException('Failed to save new race: $e');
    }
  }

  Future<void> updateRace(RaceRecord race) async {
    final db = await database;
    try {
      await db.update(
        'race_history',
        race.toMap(),
        where: 'race_id = ? AND type = ?',
        whereArgs: [race.raceId, race.type],
      );
    } catch (e) {
      throw DatabaseException('Failed to update race: $e');
    }
  }

  Future<void> updateRaceDuration(
      int raceId, String type, Duration? time) async {
    final db = await database;
    await db.update(
      'race_history',
      {'duration': time?.inMilliseconds},
      where: 'race_id = ? AND type = ?',
      whereArgs: [raceId, type],
    );
  }

  Future<void> updateRaceStartTime(
      int raceId, String type, DateTime? startedAt) async {
    final db = await database;
    await db.update(
      'race_history',
      {'started_at': startedAt?.millisecondsSinceEpoch},
      where: 'race_id = ? AND type = ?',
      whereArgs: [raceId, type],
    );
  }

  Future<void> updateRaceStatus(int raceId, String type, bool stopped) async {
    final db = await database;
    await db.update(
      'race_history',
      {'stopped': stopped ? 1 : 0},
      where: 'race_id = ? AND type = ?',
      whereArgs: [raceId, type],
    );
  }

  Future<List<RaceRecord>> getRecentRaces(String type,
      {Duration? since}) async {
    final db = await database;
    try {
      final cutoff = DateTime.now()
          .subtract(since ?? const Duration(days: 7))
          .millisecondsSinceEpoch;

      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'date > ? AND type = ?',
        whereArgs: [cutoff, type],
        orderBy: 'date DESC',
      );

      return races.map((race) => RaceRecord.fromMap(race)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get recent races: $e');
    }
  }

  Future<List<RaceRecord>> getRaces(String type) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'date DESC',
      );

      return races.map((race) => RaceRecord.fromMap(race)).toList();
    } catch (e) {
      Logger.e('Failed to get races: $e');
      throw DatabaseException('Failed to get races: $e');
    }
  }

  Future<RaceRecord?> getRace(int raceId, String type) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
        limit: 1,
      );

      if (races.isEmpty) return null;
      return RaceRecord.fromMap(races.first);
    } catch (e) {
      throw DatabaseException('Failed to get race: $e');
    }
  }

  Future<void> deleteRace(int raceId, String type) async {
    final db = await database;
    try {
      // Delete all chunks first (foreign key constraint)
      await db.delete(
        'timing_chunks',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );

      // Delete the race
      await db.delete(
        'race_history',
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
      );
    } catch (e) {
      throw DatabaseException('Failed to delete race: $e');
    }
  }

  // Chunk methods
  Future<void> saveChunk(int raceId, TimingChunk chunk) async {
    final db = await database;
    try {
      final data = {
        'race_id': raceId,
        'chunk_id': chunk.id,
        'timing_data':
            chunk.timingData.map((record) => record.encode()).join(','),
        'conflict_record': chunk.conflictRecord?.encode(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await db.insert(
        'timing_chunks',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.e('Failed to save chunk ID: ${chunk.id} for race ID: $raceId: $e');
      throw DatabaseException('Failed to save chunk: $e');
    }
  }

  Future<TimingChunk?> getChunk(int raceId, int chunkId) async {
    final db = await database;

    final chunks = await db.query(
      'timing_chunks',
      where: 'race_id = ? AND chunk_id = ?',
      whereArgs: [raceId, chunkId],
      limit: 1,
    );

    if (chunks.isEmpty) return null;

    final chunk = chunks.first;
    final records = chunk['timing_data'] != null
        ? await TimingDecodeUtils.decodeEncodedTimingData(
            chunk['timing_data'] as String)
        : [] as List<TimingDatum>;
    final conflictRecord = chunk['conflict_record'] != null
        ? TimingDatum.fromEncodedString(chunk['conflict_record'] as String)
        : null;

    return TimingChunk(
      id: chunkId,
      timingData: records,
      conflictRecord: conflictRecord,
    );
  }

  Future<String?> getChunkTimingData(int raceId, int chunkId) async {
    final db = await database;
    final chunk = await db.query(
      'timing_chunks',
      columns: ['timing_data'],
      where: 'race_id = ? AND chunk_id = ?',
      whereArgs: [raceId, chunkId],
      limit: 1,
    );
    return chunk.isEmpty ? null : chunk.first['timing_data'] as String;
  }

  Future<List<TimingChunk>> getChunks(int raceId) async {
    final db = await database;

    final chunks = await db.query(
      'timing_chunks',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'created_at ASC',
    );

    final List<TimingChunk> result = [];
    for (final chunk in chunks) {
      final chunkId = chunk['chunk_id'] as int;
      final timingData = chunk['timing_data'] != null
          ? await TimingDecodeUtils.decodeEncodedTimingData(
              chunk['timing_data'] as String)
          : [] as List<TimingDatum>;
      final conflictRecord = chunk['conflict_record'] != null
          ? TimingDatum.fromEncodedString(chunk['conflict_record'] as String)
          : null;

      result.add(TimingChunk(
        id: chunkId,
        timingData: timingData,
        conflictRecord: conflictRecord,
      ));
    }

    return result;
  }

  Future<void> deleteChunk(int raceId, int chunkId) async {
    final db = await database;
    try {
      await db.delete(
        'timing_chunks',
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
    } catch (e) {
      throw DatabaseException('Failed to delete chunk: $e');
    }
  }

  Future<void> deleteChunks(int raceId) async {
    final db = await database;
    await db.delete(
      'timing_chunks',
      where: 'race_id = ?',
      whereArgs: [raceId],
    );
  }

  // Chunk conflict methods
  Future<void> saveChunkConflict(
      int raceId, int chunkId, TimingDatum conflictRecord) async {
    final db = await database;
    try {
      await db.update(
        'timing_chunks',
        {'conflict_record': conflictRecord.encode()},
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
    } catch (e) {
      Logger.e(
          'Failed to save chunk conflict for chunk ID: $chunkId in race ID: $raceId: $e');
      throw DatabaseException('Failed to save chunk conflict: $e');
    }
  }

  Future<void> updateChunkConflict(
      String chunkId, TimingDatum? conflictRecord) async {
    final db = await database;
    try {
      if (conflictRecord == null) {
        await db.delete(
          'chunk_conflicts',
          where: 'chunk_id = ?',
          whereArgs: [chunkId],
        );
      } else {
        await db.update(
          'chunk_conflicts',
          {'conflict_data': conflictRecord.encode()},
          where: 'chunk_id = ?',
          whereArgs: [chunkId],
        );
      }
    } catch (e) {
      throw DatabaseException('Failed to update chunk conflict: $e');
    }
  }

  Future<String?> getChunkConflict(String chunkId) async {
    final db = await database;
    try {
      final conflicts = await db.query(
        'chunk_conflicts',
        columns: ['conflict_data'],
        where: 'chunk_id = ?',
        whereArgs: [chunkId],
        limit: 1,
      );

      return conflicts.isEmpty
          ? null
          : conflicts.first['conflict_data'] as String;
    } catch (e) {
      throw DatabaseException('Failed to get chunk conflict: $e');
    }
  }

  // Chunk timing data methods
  Future<void> saveChunkTimingData(
      String chunkId, List<String> encodedRecords) async {
    final db = await database;
    try {
      for (final record in encodedRecords) {
        await db.insert(
          'chunk_timing_data',
          {
            'chunk_id': chunkId,
            'record_data': record,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    } catch (e) {
      throw DatabaseException('Failed to save chunk timing data: $e');
    }
  }

  Future<void> updateChunkTimingData(
      int raceId, int chunkId, List<TimingDatum> timingData) async {
    final db = await database;
    try {
      await db.update(
        'timing_chunks',
        {'timing_data': TimingEncodeUtils.encodeTimeRecords(timingData)},
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
    } catch (e) {
      Logger.e(
          'Failed to update chunk timing data for chunk ID: $chunkId in race ID: $raceId: $e');
      throw DatabaseException('Failed to update chunk timing data: $e');
    }
  }

  Future<void> addLoggedTimingDatum(
      int raceId, int chunkId, TimingDatum datum) async {
    // Append the encoded datum to the end of the chunk's timing data
    final db = await database;
    try {
      // Get the current encoded timing data for the chunk
      final timingData = await getChunkTimingData(raceId, chunkId);

      String updatedTimingData;
      final encodedDatum = datum.encode();

      if (timingData == null || timingData.isEmpty) {
        updatedTimingData = encodedDatum;
      } else {
        updatedTimingData = '$timingData,$encodedDatum';
      }

      await db.update(
        'timing_chunks',
        {'timing_data': updatedTimingData},
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
    } catch (e) {
      Logger.e(
          'Failed to add logged timing datum to chunk ID: $chunkId in race ID: $raceId: $e');
      throw DatabaseException('Failed to add logged timing datum: $e');
    }
  }

  Future<void> deleteOldRaces({Duration? olderThan}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(olderThan ?? const Duration(days: 7))
        .millisecondsSinceEpoch;

    await db.delete(
      'race_history',
      where: 'date < ?',
      whereArgs: [cutoff],
    );
  }

  // Runner Methods
  // ============================================================================

  Future<void> saveRunner(Runner runner) async {
    final db = await database;
    try {
      await db.insert(
        'runners',
        runner.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.e('Failed to save runner: $e');
      throw DatabaseException('Failed to save runner: $e');
    }
  }

  Future<void> saveRunners(int raceId, List<Runner> runners) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Clear existing runners for this race
        await txn.delete(
          'runners',
          where: 'race_id = ?',
          whereArgs: [raceId],
        );

        // Insert new runners
        for (final runner in runners) {
          await txn.insert(
            'runners',
            runner.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      Logger.e('Failed to save runners: $e');
      throw DatabaseException('Failed to save runners: $e');
    }
  }

  Future<Runner?> getRunner(int raceId, String bibNumber) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> records = await db.query(
        'runners',
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [raceId, bibNumber],
        limit: 1,
      );

      if (records.isEmpty) return null;
      return Runner.fromMap(records.first);
    } catch (e) {
      Logger.e('Failed to get runner: $e');
      throw DatabaseException('Failed to get runner: $e');
    }
  }

  Future<List<Runner>> getRunners(int raceId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> records = await db.query(
        'runners',
        where: 'race_id = ?',
        whereArgs: [raceId],
        orderBy: 'created_at ASC',
      );

      return records.map((record) => Runner.fromMap(record)).toList();
    } catch (e) {
      Logger.e('Failed to get runners: $e');
      throw DatabaseException('Failed to get runners: $e');
    }
  }

  Future<void> updateRunner(Runner runner) async {
    final db = await database;
    try {
      await db.update(
        'runners',
        runner.toMap(),
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [runner.raceId, runner.bibNumber],
      );
    } catch (e) {
      Logger.e('Failed to update runner: $e');
      throw DatabaseException('Failed to update runner: $e');
    }
  }

  Future<void> deleteRunner(int raceId, String bibNumber) async {
    final db = await database;
    try {
      await db.delete(
        'runners',
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [raceId, bibNumber],
      );
    } catch (e) {
      Logger.e('Failed to delete runner: $e');
      throw DatabaseException('Failed to delete runner: $e');
    }
  }

  Future<void> deleteRunners(int raceId) async {
    final db = await database;
    try {
      await db.delete(
        'runners',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
    } catch (e) {
      Logger.e('Failed to delete runners: $e');
      throw DatabaseException('Failed to delete runners: $e');
    }
  }

  // Bib Records Methods
  // ============================================================================

  Future<void> saveBibRecord(BibRecord bibRecord) async {
    final db = await database;
    try {
      await db.insert(
        'bib_records',
        bibRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.e('Failed to save bib record: $e');
      throw DatabaseException('Failed to save bib record: $e');
    }
  }

  Future<void> saveBibRecords(int raceId, List<BibRecord> bibRecords) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Clear existing bib records for this race
        await txn.delete(
          'bib_records',
          where: 'race_id = ?',
          whereArgs: [raceId],
        );

        // Insert new bib records
        for (final bibRecord in bibRecords) {
          await txn.insert(
            'bib_records',
            bibRecord.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      Logger.e('Failed to save bib records: $e');
      throw DatabaseException('Failed to save bib records: $e');
    }
  }

  /// Adds a single bib record to the database
  Future<void> addBibRecord(int raceId, int bibId, String bibNumber) async {
    final db = await database;
    try {
      final record = BibRecord(
        raceId: raceId,
        bibId: bibId,
        bibNumber: bibNumber,
        createdAt: DateTime.now(),
      );
      await db.insert(
        'bib_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.e('Failed to add bib record: $e');
      throw DatabaseException('Failed to add bib record: $e');
    }
  }

  /// Removes a single bib record from the database
  Future<void> removeBibRecord(int raceId, int bibId) async {
    final db = await database;
    try {
      await db.delete(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
    } catch (e) {
      Logger.e('Failed to remove bib record: $e');
      throw DatabaseException('Failed to remove bib record: $e');
    }
  }

  /// Updates a single bib record in the database
  Future<void> updateBibRecordValue(
      int raceId, int bibId, String bibNumber) async {
    final db = await database;
    try {
      await db.update(
        'bib_records',
        {
          'bib_number': bibNumber,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
    } catch (e) {
      Logger.e('Failed to update bib record: $e');
      throw DatabaseException('Failed to update bib record: $e');
    }
  }

  Future<BibRecord?> getBibRecord(int raceId, int bibId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> records = await db.query(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
        limit: 1,
      );

      if (records.isEmpty) return null;
      return BibRecord.fromMap(records.first);
    } catch (e) {
      Logger.e('Failed to get bib record: $e');
      throw DatabaseException('Failed to get bib record: $e');
    }
  }

  Future<List<BibRecord>> getBibRecords(int raceId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> records = await db.query(
        'bib_records',
        where: 'race_id = ?',
        whereArgs: [raceId],
        orderBy: 'created_at ASC',
      );

      return records.map((record) => BibRecord.fromMap(record)).toList();
    } catch (e) {
      Logger.e('Failed to get bib records: $e');
      throw DatabaseException('Failed to get bib records: $e');
    }
  }

  Future<void> updateBibRecord(BibRecord bibRecord) async {
    final db = await database;
    try {
      await db.update(
        'bib_records',
        bibRecord.toMap(),
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [bibRecord.raceId, bibRecord.bibId],
      );
    } catch (e) {
      Logger.e('Failed to update bib record: $e');
      throw DatabaseException('Failed to update bib record: $e');
    }
  }

  Future<void> deleteBibRecord(int raceId, int bibId) async {
    final db = await database;
    try {
      await db.delete(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
    } catch (e) {
      Logger.e('Failed to delete bib record: $e');
      throw DatabaseException('Failed to delete bib record: $e');
    }
  }

  Future<void> deleteBibRecords(int raceId) async {
    final db = await database;
    try {
      await db.delete(
        'bib_records',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
    } catch (e) {
      Logger.e('Failed to delete bib records: $e');
      throw DatabaseException('Failed to delete bib records: $e');
    }
  }

  Future<int> getNextBibId(int raceId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT MAX(bib_id) as max_id FROM bib_records WHERE race_id = ?',
        [raceId],
      );

      final maxId = result.first['max_id'] as int?;
      return (maxId ?? 0) + 1;
    } catch (e) {
      Logger.e('Failed to get next bib ID: $e');
      throw DatabaseException('Failed to get next bib ID: $e');
    }
  }
}
