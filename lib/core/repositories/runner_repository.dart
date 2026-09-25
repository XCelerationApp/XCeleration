import 'package:sqflite/sqflite.dart';
import '../app_error.dart';
import '../../shared/models/database/base_models.dart';
import '../services/database_write_bus.dart';
import 'i_database_connection_provider.dart';
import 'i_runner_repository.dart';
import 'package:xceleration/core/utils/sync_timestamp.dart';

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
      'updated_at': SyncTimestamp.now(),
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
    final rows =
        await db.query('runners', where: 'deleted_at IS NULL', orderBy: 'name');
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
  Future<int> countRaceResults(int runnerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM race_results '
        'WHERE runner_id = ? AND deleted_at IS NULL',
        [runnerId]);
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Refuses to delete a runner whose results the delete would cascade away.
  Future<void> _ensureNoRaceResults(int runnerId) async {
    if (await countRaceResults(runnerId) > 0) {
      throw const DataInUseException(
          'This runner has saved race results, so they cannot be deleted.');
    }
  }

  @override
  Future<void> removeRunner(int runnerId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    await _ensureNoRaceResults(runnerId);
    final db = await _db;
    await _tombstoneRunner(db, runnerId);
    _writeBus?.notify();
  }

  @override
  Future<void> deleteRunnerEverywhere(int runnerId) async {
    if (await getRunner(runnerId) == null) return;
    await _ensureNoRaceResults(runnerId);
    final db = await _db;
    final now = SyncTimestamp.now();
    await db.transaction((txn) async {
      for (final table in ['race_participants', 'team_rosters']) {
        await txn.update(
          table,
          {'deleted_at': now, 'updated_at': now, 'is_dirty': 1},
          where: 'runner_id = ? AND deleted_at IS NULL',
          whereArgs: [runnerId],
        );
      }
      await txn.update(
        'runners',
        {'deleted_at': now, 'updated_at': now, 'is_dirty': 1},
        where: 'runner_id = ?',
        whereArgs: [runnerId],
      );
    });
    _writeBus?.notify();
  }

  /// Marks a runner deleted rather than removing the row, so the deletion can
  /// be pushed. Uniqueness on the bib number ignores deleted rows, so the bib
  /// is free for someone else straight away.
  Future<void> _tombstoneRunner(DatabaseExecutor db, int runnerId) async {
    final now = SyncTimestamp.now();
    await db.update(
      'runners',
      {'deleted_at': now, 'updated_at': now, 'is_dirty': 1},
      where: 'runner_id = ?',
      whereArgs: [runnerId],
    );
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
    // Replace, not ignore: putting a runner back on a team they were removed
    // from has to clear the tombstone, which ignore would leave in place.
    await db.insert(
      'team_rosters',
      {
        'team_id': teamId,
        'runner_id': runnerId,
        'is_dirty': 1,
        'updated_at': SyncTimestamp.now(),
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
    // Tombstone rather than delete: a removed row cannot be pushed, so the
    // server would keep the runner on the team and put them back on the next
    // pull.
    await db.update(
      'team_rosters',
      {
        'deleted_at': SyncTimestamp.now(),
        'updated_at': SyncTimestamp.now(),
        'is_dirty': 1,
      },
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
        .query('teams',
            where: 'team_id = ? AND deleted_at IS NULL',
            whereArgs: [newTeamId],
            limit: 1);
    if (teamRows.isEmpty) throw Exception('Team with id $newTeamId not found');
    final now = SyncTimestamp.now();
    await db.transaction((txn) async {
      await txn.update(
        'team_rosters',
        {'deleted_at': now, 'updated_at': now, 'is_dirty': 1},
        where: 'runner_id = ? AND deleted_at IS NULL',
        whereArgs: [runnerId],
      );
      await txn.insert(
        'team_rosters',
        {
          'team_id': newTeamId,
          'runner_id': runnerId,
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
        AND tr.deleted_at IS NULL AND r.deleted_at IS NULL
    ''', [teamId, runnerId]);
    return rows.isNotEmpty ? Runner.fromMap(rows.first) : null;
  }

  @override
  Future<List<Runner>> getTeamRunners(int teamId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.* FROM runners r
      JOIN team_rosters tr ON r.runner_id = tr.runner_id
      WHERE tr.team_id = ? AND tr.deleted_at IS NULL AND r.deleted_at IS NULL
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
      WHERE tr.runner_id = ? AND tr.deleted_at IS NULL AND t.deleted_at IS NULL
      ORDER BY t.name
    ''', [runnerId]);
    return rows.map((m) => Team.fromMap(m)).toList();
  }
}
