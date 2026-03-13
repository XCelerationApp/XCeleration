import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';
import '../services/database_write_bus.dart';
import 'i_database_connection_provider.dart';
import 'i_results_repository.dart';

class ResultsRepository implements IResultsRepository {
  final IDatabaseConnectionProvider _conn;
  final DatabaseWriteBus? _writeBus;

  ResultsRepository({
    required IDatabaseConnectionProvider conn,
    DatabaseWriteBus? writeBus,
  })  : _conn = conn,
        _writeBus = writeBus;

  Future<Database> get _db async => _conn.database;

  @override
  Future<void> saveRaceResults(int raceId, List<RaceResult> results) async {
    for (final result in results) {
      if (!result.isValid) {
        throw Exception('RaceResult is not valid: ${result.toString()}');
      }
    }
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      for (final result in results) {
        await txn.insert('race_results', result.toMap());
      }
    });
    _writeBus?.notify();
  }

  @override
  Future<void> addRaceResult(RaceResult result) async {
    if (result.raceId != null && result.runner?.runnerId != null) {
      final db = await _db;
      final existing = await db.query(
        'race_results',
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [result.raceId, result.runner!.runnerId],
      );
      if (existing.isNotEmpty) throw Exception('RaceResult already exists');
    }
    final db = await _db;
    final map = result.toMap();
    map['is_dirty'] = 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    await db.insert('race_results', map);
    _writeBus?.notify();
  }

  @override
  Future<RaceResult?> getRaceResult(RaceResult raceResult) async {
    if (raceResult.raceId == null || raceResult.runner?.runnerId == null) {
      throw Exception(
          'RaceResult must have raceId and runnerId to check existence');
    }
    final db = await _db;
    final rows = await db.query(
      'race_results',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!],
    );
    return rows.isNotEmpty ? RaceResult.fromMap(rows.first) : null;
  }

  @override
  Future<List<RaceResult>> getRaceResults(int raceId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        rr.runner_id,
        r.bib_number,
        r.name,
        rr.team_id,
        t.name as team_name,
        t.abbreviation as team_abbreviation,
        t.color as team_color,
        r.grade,
        rr.place,
        rr.finish_time,
        rr.race_id
      FROM race_results rr
      JOIN runners r ON rr.runner_id = r.runner_id
      LEFT JOIN teams t ON rr.team_id = t.team_id
      WHERE rr.race_id = ?
      ORDER BY rr.place
    ''', [raceId]);
    return rows.map((m) => RaceResult.fromMap(m)).toList();
  }

  @override
  Future<void> updateRaceResult(RaceResult raceResult) async {
    if (!raceResult.isValid) throw Exception('RaceResult is not valid');
    if (await getRaceResult(raceResult) == null) {
      throw Exception(
          'Result for runner ${raceResult.runner?.runnerId} in race ${raceResult.raceId} not found');
    }
    final db = await _db;
    final map = raceResult.toMap();
    map['is_dirty'] = 1;
    await db.update('race_results', map,
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!]);
    _writeBus?.notify();
  }

  @override
  Future<void> deleteRaceResult(RaceResult raceResult) async {
    if (raceResult.raceId == null || raceResult.runner?.runnerId == null) {
      throw Exception('Race or runner not given');
    }
    if (await getRaceResult(raceResult) == null) {
      throw Exception(
          'Result for runner ${raceResult.runner?.runnerId} in race ${raceResult.raceId} not found');
    }
    final db = await _db;
    await db.delete(
      'race_results',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!],
    );
    _writeBus?.notify();
  }
}
