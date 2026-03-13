import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';
import '../services/database_write_bus.dart';
import 'i_database_connection_provider.dart';
import 'i_runner_repository.dart';

class RunnerRepository implements IRunnerRepository {
  final IDatabaseConnectionProvider _conn;
  final DatabaseWriteBus? _writeBus;

  RunnerRepository({
    required IDatabaseConnectionProvider conn,
    DatabaseWriteBus? writeBus,
  })  : _conn = conn,
        _writeBus = writeBus;

  Future<Database> get _db async => _conn.database;

  // ============================================================================
  // CRUD
  // ============================================================================

  @override
  Future<int> createRunner(Runner runner) async {
    if (!runner.isValid) throw Exception('Runner is not valid');
    if (await getRunnerByBib(runner.bibNumber!) != null) {
      throw Exception(
          'Runner with bib number ${runner.bibNumber} already exists');
    }
    final db = await _db;
    final id = await db.insert('runners', {
      'name': runner.name,
      'bib_number': runner.bibNumber,
      'grade': runner.grade,
      'is_dirty': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
    _writeBus?.notify();
    return id;
  }

  @override
  Future<Runner?> getRunner(int runnerId) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'runner_id = ?',
      whereArgs: [runnerId],
    );
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<Runner?> getRunnerByBib(String bibNumber) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'bib_number = ?',
      whereArgs: [bibNumber],
    );
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<List<Runner>> getAllRunners() async {
    final db = await _db;
    final rows = await db.query('runners', orderBy: 'name');
    return rows.map((m) => Runner.fromMap(m)).toList();
  }

  @override
  Future<List<Runner>> searchRunners(String query) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'name LIKE ? OR bib_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return rows.map((m) => Runner.fromMap(m)).toList();
  }

  @override
  Future<void> updateRunner(Runner runner) async {
    if (runner.runnerId == null) throw Exception('Runner id is required');
    if (!runner.isValid) throw Exception('Runner is not valid');
    final db = await _db;
    final map = runner.toMap();
    map['is_dirty'] = 1;
    await db.update('runners', map,
        where: 'runner_id = ?', whereArgs: [runner.runnerId]);
    _writeBus?.notify();
  }

  @override
  Future<void> removeRunner(int runnerId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    final db = await _db;
    await db.delete('runners', where: 'runner_id = ?', whereArgs: [runnerId]);
    _writeBus?.notify();
  }

  @override
  Future<void> deleteRunnerEverywhere(int runnerId) async {
    if (await getRunner(runnerId) == null) return;
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('race_participants',
          where: 'runner_id = ?', whereArgs: [runnerId]);
      await txn
          .delete('team_rosters', where: 'runner_id = ?', whereArgs: [runnerId]);
      await txn
          .delete('runners', where: 'runner_id = ?', whereArgs: [runnerId]);
    });
    _writeBus?.notify();
  }

  @override
  Future<List<Runner>> getRunnersByBibAll(String bib) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
    return rows.map((m) => Runner.fromMap(m)).toList();
  }

  // ============================================================================
  // TEAM ROSTER
  // ============================================================================

  @override
  Future<void> addRunnerToTeam(int teamId, int runnerId) async {
    if (await getTeamRunner(teamId, runnerId) != null) return;
    final db = await _db;
    await db.insert(
      'team_rosters',
      {'team_id': teamId, 'runner_id': runnerId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _writeBus?.notify();
  }

  @override
  Future<void> removeRunnerFromTeam(int teamId, int runnerId) async {
    if (await getTeamRunner(teamId, runnerId) == null) {
      throw Exception('Runner $runnerId not in team $teamId');
    }
    final db = await _db;
    await db.delete(
      'team_rosters',
      where: 'team_id = ? AND runner_id = ?',
      whereArgs: [teamId, runnerId],
    );
    _writeBus?.notify();
  }

  @override
  Future<void> setRunnerTeam(int runnerId, int newTeamId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    // Validate team existence via raw SQL (avoids cross-repo dep)
    final db = await _db;
    final teamRows = await db
        .query('teams', where: 'team_id = ?', whereArgs: [newTeamId], limit: 1);
    if (teamRows.isEmpty) throw Exception('Team with id $newTeamId not found');
    await db.transaction((txn) async {
      await txn.delete('team_rosters',
          where: 'runner_id = ?', whereArgs: [runnerId]);
      await txn.insert(
        'team_rosters',
        {'team_id': newTeamId, 'runner_id': runnerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _writeBus?.notify();
  }

  @override
  Future<Runner?> getTeamRunner(int teamId, int runnerId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.* FROM runners r
      JOIN team_rosters tr ON r.runner_id = tr.runner_id
      WHERE tr.team_id = ? AND tr.runner_id = ?
    ''', [teamId, runnerId]);
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<List<Runner>> getTeamRunners(int teamId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.* FROM runners r
      JOIN team_rosters tr ON r.runner_id = tr.runner_id
      WHERE tr.team_id = ?
      ORDER BY r.name
    ''', [teamId]);
    return rows.map((m) => Runner.fromMap(m)).toList();
  }

  @override
  Future<List<Team>> getRunnerTeams(int runnerId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.* FROM teams t
      JOIN team_rosters tr ON t.team_id = tr.team_id
      WHERE tr.runner_id = ?
      ORDER BY t.name
    ''', [runnerId]);
    return rows.map((m) => Team.fromMap(m)).toList();
  }
}
