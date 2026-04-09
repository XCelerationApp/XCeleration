import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/database/base_models.dart';
import '../services/database_write_bus.dart';
import 'i_database_connection_provider.dart';
import 'i_runner_repository.dart';

class RunnerRepository implements IRunnerRepository {
  final IDatabaseConnectionProvider _conn;
  final DatabaseWriteBus? _writeBus;
  final _uuid = const Uuid();

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
      where: 'runner_id = ? AND deleted_at IS NULL',
      whereArgs: [runnerId],
    );
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<Runner?> getRunnerByBib(String bibNumber) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'bib_number = ? AND deleted_at IS NULL',
      whereArgs: [bibNumber],
    );
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<List<Runner>> getAllRunners() async {
    final db = await _db;
    final rows = await db.query('runners', where: 'deleted_at IS NULL', orderBy: 'name');
    return rows.map((m) => Runner.fromMap(m)).toList();
  }

  @override
  Future<List<Runner>> searchRunners(String query) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'deleted_at IS NULL AND (name LIKE ? OR bib_number LIKE ?)',
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
    final now = DateTime.now().toIso8601String();
    await db.update(
      'runners',
      {'deleted_at': now, 'is_dirty': 1, 'updated_at': now},
      where: 'runner_id = ?',
      whereArgs: [runnerId],
    );
    _writeBus?.notify();
  }

  @override
  Future<void> deleteRunnerEverywhere(int runnerId) async {
    if (await getRunner(runnerId) == null) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE race_participants SET deleted_at = ?, is_dirty = 1, updated_at = ? WHERE runner_id = ? AND deleted_at IS NULL',
        [now, now, runnerId],
      );
      await txn.rawUpdate(
        'UPDATE team_rosters SET deleted_at = ?, is_dirty = 1, updated_at = ? WHERE runner_id = ? AND deleted_at IS NULL',
        [now, now, runnerId],
      );
      await txn.rawUpdate(
        'UPDATE runners SET deleted_at = ?, is_dirty = 1, updated_at = ? WHERE runner_id = ?',
        [now, now, runnerId],
      );
    });
    _writeBus?.notify();
  }

  @override
  Future<List<Runner>> getRunnersByBibAll(String bib) async {
    final db = await _db;
    final rows = await db.query(
      'runners',
      where: 'bib_number = ? AND deleted_at IS NULL',
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
    final teamRows = await db.query('teams',
        columns: ['uuid'], where: 'team_id = ?', whereArgs: [teamId], limit: 1);
    final runnerRows = await db.query('runners',
        columns: ['uuid'],
        where: 'runner_id = ?',
        whereArgs: [runnerId],
        limit: 1);
    await db.insert(
      'team_rosters',
      {
        'team_id': teamId,
        'runner_id': runnerId,
        'uuid': _uuid.v4(),
        'team_uuid': teamRows.isNotEmpty ? teamRows.first['uuid'] : null,
        'runner_uuid': runnerRows.isNotEmpty ? runnerRows.first['uuid'] : null,
        'is_dirty': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _writeBus?.notify();
  }

  @override
  Future<void> removeRunnerFromTeam(int teamId, int runnerId) async {
    if (await getTeamRunner(teamId, runnerId) == null) {
      throw Exception('Runner $runnerId not in team $teamId');
    }
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'team_rosters',
      {'deleted_at': now, 'is_dirty': 1, 'updated_at': now},
      where: 'team_id = ? AND runner_id = ? AND deleted_at IS NULL',
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
    final teamRows = await db.query('teams',
        where: 'team_id = ? AND deleted_at IS NULL',
        whereArgs: [newTeamId],
        limit: 1);
    if (teamRows.isEmpty) throw Exception('Team with id $newTeamId not found');
    final teamUuid = teamRows.first['uuid'] as String?;
    final runnerRows = await db.query('runners',
        columns: ['uuid'],
        where: 'runner_id = ?',
        whereArgs: [runnerId],
        limit: 1);
    final runnerUuid =
        runnerRows.isNotEmpty ? runnerRows.first['uuid'] as String? : null;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE team_rosters SET deleted_at = ?, is_dirty = 1, updated_at = ? WHERE runner_id = ? AND deleted_at IS NULL',
        [now, now, runnerId],
      );
      await txn.insert(
        'team_rosters',
        {
          'team_id': newTeamId,
          'runner_id': runnerId,
          'uuid': _uuid.v4(),
          'team_uuid': teamUuid,
          'runner_uuid': runnerUuid,
          'is_dirty': 1,
          'updated_at': now,
        },
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
        AND r.deleted_at IS NULL AND tr.deleted_at IS NULL
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
        AND r.deleted_at IS NULL AND tr.deleted_at IS NULL
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
        AND t.deleted_at IS NULL AND tr.deleted_at IS NULL
      ORDER BY t.name
    ''', [runnerId]);
    return rows.map((m) => Team.fromMap(m)).toList();
  }
}
