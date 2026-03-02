import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/race_record.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import '../models/bib_record.dart';
import '../models/runner.dart';
import 'i_assistant_storage_service.dart';

/// Shared storage service for assistant mode features (race timing and bib recording)
class AssistantStorageService implements IAssistantStorageService {
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

  @override
  Future<Result<void>> saveNewRace(RaceRecord race) async {
    try {
      final db = await database;
      final existing = await db.query(
        'race_history',
        where: 'race_id = ? AND type = ?',
        whereArgs: [race.raceId, race.type],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        Logger.e(
            'Race already exists in database: ${race.raceId} (${race.type})');
        return Failure(const AppError(userMessage: 'Race is already loaded.'));
      }
      await db.insert(
        'race_history',
        race.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not save the race. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateRace(RaceRecord race) async {
    try {
      final db = await database;
      await db.update(
        'race_history',
        race.toMap(),
        where: 'race_id = ? AND type = ?',
        whereArgs: [race.raceId, race.type],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update the race. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateRaceDuration(
      int raceId, String type, Duration? time) async {
    try {
      final db = await database;
      await db.update(
        'race_history',
        {'duration': time?.inMilliseconds},
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update the race duration.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateRaceStartTime(
      int raceId, String type, DateTime? startedAt) async {
    try {
      final db = await database;
      await db.update(
        'race_history',
        {'started_at': startedAt?.millisecondsSinceEpoch},
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update the race start time.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateRaceStatus(
      int raceId, String type, bool stopped) async {
    try {
      final db = await database;
      await db.update(
        'race_history',
        {'stopped': stopped ? 1 : 0},
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update the race status.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<List<RaceRecord>>> getRecentRaces(String type,
      {Duration? since}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(since ?? const Duration(days: 7))
          .millisecondsSinceEpoch;

      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'date > ? AND type = ?',
        whereArgs: [cutoff, type],
        orderBy: 'date DESC',
      );

      return Success(races.map((race) => RaceRecord.fromMap(race)).toList());
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load recent races. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<List<RaceRecord>>> getRaces(String type) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'date DESC',
      );

      return Success(races.map((race) => RaceRecord.fromMap(race)).toList());
    } catch (e) {
      Logger.e('Failed to get races: $e');
      return Failure(AppError(
        userMessage: 'Could not load races. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<RaceRecord?>> getRace(int raceId, String type) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> races = await db.query(
        'race_history',
        where: 'race_id = ? AND type = ?',
        whereArgs: [raceId, type],
        limit: 1,
      );

      if (races.isEmpty) return const Success(null);
      return Success(RaceRecord.fromMap(races.first));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load the race. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteRace(int raceId, String type) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not delete the race. Please try again.',
        originalException: e,
      ));
    }
  }

  // Chunk methods

  @override
  Future<Result<void>> saveChunk(int raceId, TimingChunk chunk) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to save chunk ID: ${chunk.id} for race ID: $raceId: $e');
      return Failure(AppError(
        userMessage: 'Could not save timing data. Please try again.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<TimingChunk?>> getChunk(int raceId, int chunkId) async {
    try {
      final db = await database;
      final chunks = await db.query(
        'timing_chunks',
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
        limit: 1,
      );

      if (chunks.isEmpty) return const Success(null);

      final chunk = chunks.first;
      final records = chunk['timing_data'] != null
          ? await TimingDecodeUtils.decodeEncodedTimingData(
              chunk['timing_data'] as String)
          : [] as List<TimingDatum>;
      final conflictRecord = chunk['conflict_record'] != null
          ? TimingDatum.fromEncodedString(chunk['conflict_record'] as String)
          : null;

      return Success(TimingChunk(
        id: chunkId,
        timingData: records,
        conflictRecord: conflictRecord,
      ));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load timing chunk.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<String?>> getChunkTimingData(int raceId, int chunkId) async {
    try {
      final db = await database;
      final chunk = await db.query(
        'timing_chunks',
        columns: ['timing_data'],
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
        limit: 1,
      );
      return Success(
          chunk.isEmpty ? null : chunk.first['timing_data'] as String?);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load timing data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<List<TimingChunk>>> getChunks(int raceId) async {
    try {
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
                chunk['timing_data'] as String,
                isFromDatabase: true)
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

      return Success(result);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load timing chunks.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteChunk(int raceId, int chunkId) async {
    try {
      final db = await database;
      await db.delete(
        'timing_chunks',
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not delete timing chunk.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteChunks(int raceId) async {
    try {
      final db = await database;
      await db.delete(
        'timing_chunks',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not delete timing data.',
        originalException: e,
      ));
    }
  }

  // Chunk conflict methods

  @override
  Future<Result<void>> saveChunkConflict(
      int raceId, int chunkId, TimingDatum conflictRecord) async {
    try {
      final db = await database;
      await db.update(
        'timing_chunks',
        {'conflict_record': conflictRecord.encode()},
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e(
          'Failed to save chunk conflict for chunk ID: $chunkId in race ID: $raceId: $e');
      return Failure(AppError(
        userMessage: 'Could not save conflict record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateChunkConflict(
      String chunkId, TimingDatum? conflictRecord) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not update conflict record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<String?>> getChunkConflict(String chunkId) async {
    try {
      final db = await database;
      final conflicts = await db.query(
        'chunk_conflicts',
        columns: ['conflict_data'],
        where: 'chunk_id = ?',
        whereArgs: [chunkId],
        limit: 1,
      );

      return Success(conflicts.isEmpty
          ? null
          : conflicts.first['conflict_data'] as String?);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not load conflict record.',
        originalException: e,
      ));
    }
  }

  // Chunk timing data methods

  @override
  Future<Result<void>> saveChunkTimingData(
      String chunkId, List<String> encodedRecords) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not save timing records.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateChunkTimingData(
      int raceId, int chunkId, List<TimingDatum> timingData) async {
    try {
      final db = await database;
      await db.update(
        'timing_chunks',
        {'timing_data': TimingEncodeUtils.encodeTimeRecords(timingData)},
        where: 'race_id = ? AND chunk_id = ?',
        whereArgs: [raceId, chunkId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e(
          'Failed to update chunk timing data for chunk ID: $chunkId in race ID: $raceId: $e');
      return Failure(AppError(
        userMessage: 'Could not update timing data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> addLoggedTimingDatum(
      int raceId, int chunkId, TimingDatum datum) async {
    try {
      final db = await database;
      final chunkTimingResult = await getChunkTimingData(raceId, chunkId);
      String? timingData;
      if (chunkTimingResult case Success(:final value)) {
        timingData = value;
      }

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
      return const Success(null);
    } catch (e) {
      Logger.e(
          'Failed to add logged timing datum to chunk ID: $chunkId in race ID: $raceId: $e');
      return Failure(AppError(
        userMessage: 'Could not log timing record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteOldRaces({Duration? olderThan}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(olderThan ?? const Duration(days: 7))
          .millisecondsSinceEpoch;

      await db.delete(
        'race_history',
        where: 'date < ?',
        whereArgs: [cutoff],
      );
      return const Success(null);
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not delete old races.',
        originalException: e,
      ));
    }
  }

  // Runner Methods
  // ============================================================================

  @override
  Future<Result<void>> saveRunner(Runner runner) async {
    try {
      final db = await database;
      await db.insert(
        'runners',
        runner.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to save runner: $e');
      return Failure(AppError(
        userMessage: 'Could not save runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> saveRunners(int raceId, List<Runner> runners) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to save runners: $e');
      return Failure(AppError(
        userMessage: 'Could not save runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<Runner?>> getRunner(int raceId, String bibNumber) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> records = await db.query(
        'runners',
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [raceId, bibNumber],
        limit: 1,
      );

      if (records.isEmpty) return const Success(null);
      return Success(Runner.fromMap(records.first));
    } catch (e) {
      Logger.e('Failed to get runner: $e');
      return Failure(AppError(
        userMessage: 'Could not load runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<List<Runner>>> getRunners(int raceId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> records = await db.query(
        'runners',
        where: 'race_id = ?',
        whereArgs: [raceId],
        orderBy: 'created_at ASC',
      );

      return Success(records.map((record) => Runner.fromMap(record)).toList());
    } catch (e) {
      Logger.e('Failed to get runners: $e');
      return Failure(AppError(
        userMessage: 'Could not load runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateRunner(Runner runner) async {
    try {
      final db = await database;
      await db.update(
        'runners',
        runner.toMap(),
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [runner.raceId, runner.bibNumber],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to update runner: $e');
      return Failure(AppError(
        userMessage: 'Could not update runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteRunner(int raceId, String bibNumber) async {
    try {
      final db = await database;
      await db.delete(
        'runners',
        where: 'race_id = ? AND bib_number = ?',
        whereArgs: [raceId, bibNumber],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to delete runner: $e');
      return Failure(AppError(
        userMessage: 'Could not delete runner data.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteRunners(int raceId) async {
    try {
      final db = await database;
      await db.delete(
        'runners',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to delete runners: $e');
      return Failure(AppError(
        userMessage: 'Could not delete runner data.',
        originalException: e,
      ));
    }
  }

  // Bib Records Methods
  // ============================================================================

  @override
  Future<Result<void>> saveBibRecord(BibRecord bibRecord) async {
    try {
      final db = await database;
      await db.insert(
        'bib_records',
        bibRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to save bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not save bib record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> saveBibRecords(
      int raceId, List<BibRecord> bibRecords) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to save bib records: $e');
      return Failure(AppError(
        userMessage: 'Could not save bib records.',
        originalException: e,
      ));
    }
  }

  /// Adds a single bib record to the database
  @override
  Future<Result<void>> addBibRecord(
      int raceId, int bibId, String bibNumber) async {
    try {
      final db = await database;
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
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to add bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not add bib record.',
        originalException: e,
      ));
    }
  }

  /// Removes a single bib record from the database
  @override
  Future<Result<void>> removeBibRecord(int raceId, int bibId) async {
    try {
      final db = await database;
      await db.delete(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to remove bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not remove bib record.',
        originalException: e,
      ));
    }
  }

  /// Updates a single bib record in the database
  @override
  Future<Result<void>> updateBibRecordValue(
      int raceId, int bibId, String bibNumber) async {
    try {
      final db = await database;
      await db.update(
        'bib_records',
        {
          'bib_number': bibNumber,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to update bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not update bib record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<BibRecord?>> getBibRecord(int raceId, int bibId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> records = await db.query(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
        limit: 1,
      );

      if (records.isEmpty) return const Success(null);
      return Success(BibRecord.fromMap(records.first));
    } catch (e) {
      Logger.e('Failed to get bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not load bib record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<List<BibRecord>>> getBibRecords(int raceId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> records = await db.query(
        'bib_records',
        where: 'race_id = ?',
        whereArgs: [raceId],
        orderBy: 'created_at ASC',
      );

      return Success(
          records.map((record) => BibRecord.fromMap(record)).toList());
    } catch (e) {
      Logger.e('Failed to get bib records: $e');
      return Failure(AppError(
        userMessage: 'Could not load bib records.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> updateBibRecord(BibRecord bibRecord) async {
    try {
      final db = await database;
      await db.update(
        'bib_records',
        bibRecord.toMap(),
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [bibRecord.raceId, bibRecord.bibId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to update bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not update bib record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteBibRecord(int raceId, int bibId) async {
    try {
      final db = await database;
      await db.delete(
        'bib_records',
        where: 'race_id = ? AND bib_id = ?',
        whereArgs: [raceId, bibId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to delete bib record: $e');
      return Failure(AppError(
        userMessage: 'Could not delete bib record.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<void>> deleteBibRecords(int raceId) async {
    try {
      final db = await database;
      await db.delete(
        'bib_records',
        where: 'race_id = ?',
        whereArgs: [raceId],
      );
      return const Success(null);
    } catch (e) {
      Logger.e('Failed to delete bib records: $e');
      return Failure(AppError(
        userMessage: 'Could not delete bib records.',
        originalException: e,
      ));
    }
  }

  @override
  Future<Result<int>> getNextBibId(int raceId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT MAX(bib_id) as max_id FROM bib_records WHERE race_id = ?',
        [raceId],
      );

      final maxId = result.first['max_id'] as int?;
      return Success((maxId ?? 0) + 1);
    } catch (e) {
      Logger.e('Failed to get next bib ID: $e');
      return Failure(AppError(
        userMessage: 'Could not determine next bib ID.',
        originalException: e,
      ));
    }
  }
}
