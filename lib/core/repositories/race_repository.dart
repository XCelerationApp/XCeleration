import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';
import 'i_database_connection_provider.dart';
import 'i_race_repository.dart';
import 'i_runner_repository.dart';

class RaceRepository implements IRaceRepository {
  final IDatabaseConnectionProvider _conn;
  final IRunnerRepository _runnerRepo;

  RaceRepository({
    required IDatabaseConnectionProvider conn,
    required IRunnerRepository runnerRepo,
  })  : _conn = conn,
        _runnerRepo = runnerRepo;

  Future<Database> get _db async => _conn.database;

  // ============================================================================
  // RACE CRUD
  // ============================================================================

  @override
  Future<int> createRace(Race race) async {
    if (!race.isValid) throw Exception('Race is not valid');
    final db = await _db;
    final map = race.toMap();
    map['is_dirty'] = 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('races', map);
  }

  @override
  Future<Race?> getRace(int raceId) async {
    final db = await _db;
    final rows =
        await db.query('races', where: 'race_id = ?', whereArgs: [raceId]);
    return rows.isNotEmpty ? Race.fromJson(rows.first) : null;
  }

  @override
  Future<List<Race>> getAllRaces() async {
    final db = await _db;
    final rows = await db.query('races', orderBy: 'race_date DESC');
    return rows.map((m) => Race.fromJson(m)).toList();
  }

  @override
  Future<void> updateRace(Race race) async {
    if (race.raceId == null) throw Exception('Race id is required');
    if (!race.isValid) throw Exception('Race is not valid');
    if (await getRace(race.raceId!) == null) {
      throw Exception('Race with id ${race.raceId} not found');
    }
    final db = await _db;
    final map = race.toMap();
    map['is_dirty'] = 1;
    await db
        .update('races', map, where: 'race_id = ?', whereArgs: [race.raceId]);
  }

  @override
  Future<void> deleteRace(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _db;
    await db.delete('races', where: 'race_id = ?', whereArgs: [raceId]);
  }

  // ============================================================================
  // RACE TEAM PARTICIPATION
  // ============================================================================

  @override
  Future<void> addTeamParticipantToRace(TeamParticipant teamParticipant) async {
    if (!teamParticipant.isValid) {
      throw Exception('TeamParticipant is not valid');
    }
    if (await getRaceTeamParticipant(teamParticipant) != null) {
      throw Exception(
          'Team ${teamParticipant.teamId} already in race ${teamParticipant.raceId}');
    }
    final db = await _db;
    await db.insert(
      'race_team_participation',
      {
        'race_id': teamParticipant.raceId,
        'team_id': teamParticipant.teamId,
        'team_color_override': teamParticipant.colorOverride,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeTeamParticipantFromRace(
      TeamParticipant teamParticipant) async {
    if (await getRaceTeamParticipant(teamParticipant) == null) {
      throw Exception(
          'Team ${teamParticipant.teamId} not in race ${teamParticipant.raceId}');
    }
    final db = await _db;
    await db.delete(
      'race_team_participation',
      where: 'race_id = ? AND team_id = ?',
      whereArgs: [teamParticipant.raceId!, teamParticipant.teamId!],
    );
  }

  @override
  Future<Team?> getRaceTeamParticipant(TeamParticipant teamParticipant) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*, rtp.team_color_override
      FROM teams t
      JOIN race_team_participation rtp ON t.team_id = rtp.team_id
      WHERE rtp.race_id = ? AND rtp.team_id = ?
    ''', [teamParticipant.raceId!, teamParticipant.teamId!]);
    return rows.isNotEmpty ? Team.fromRaceParticipationMap(rows.first) : null;
  }

  @override
  Future<List<Team>> getRaceTeams(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*, rtp.team_color_override
      FROM teams t
      JOIN race_team_participation rtp ON t.team_id = rtp.team_id
      WHERE rtp.race_id = ?
      ORDER BY t.name
    ''', [raceId]);
    return rows.map((m) => Team.fromRaceParticipationMap(m)).toList();
  }

  // ============================================================================
  // RACE PARTICIPANTS
  // ============================================================================

  @override
  Future<void> addRaceParticipant(RaceParticipant raceParticipant) async {
    if (!raceParticipant.isValid) {
      throw Exception('RaceParticipant is not valid');
    }
    if (await getRaceParticipant(raceParticipant) != null) {
      throw Exception(
          'Runner ${raceParticipant.runnerId} already in race ${raceParticipant.raceId}');
    }
    final db = await _db;
    await db.insert(
      'race_participants',
      {
        'race_id': raceParticipant.raceId,
        'runner_id': raceParticipant.runnerId,
        'team_id': raceParticipant.teamId,
        'is_dirty': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateRaceParticipant(RaceParticipant raceParticipant) async {
    if (await getRaceParticipant(raceParticipant) == null) {
      throw Exception('RaceParticipant not found');
    }
    final db = await _db;
    final map = raceParticipant.toMap();
    map['is_dirty'] = 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    await db.update('race_participants', map,
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!]);
  }

  @override
  Future<void> removeRaceParticipant(RaceParticipant raceParticipant) async {
    if (await getRaceParticipant(raceParticipant) == null) {
      throw Exception(
          'Runner ${raceParticipant.runnerId} not in race ${raceParticipant.raceId}');
    }
    final db = await _db;
    await db.delete(
      'race_participants',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!],
    );
  }

  @override
  Future<RaceParticipant?> getRaceParticipant(
      RaceParticipant raceParticipant) async {
    final db = await _db;
    final rows = await db.query(
      'race_participants',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!],
    );
    return rows.isNotEmpty ? RaceParticipant.fromMap(rows.first) : null;
  }

  @override
  Future<List<RaceParticipant>> getRaceParticipants(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _db;
    final rows = await db.query(
      'race_participants',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'runner_id',
    );
    return rows.map((m) => RaceParticipant.fromMap(m)).toList();
  }

  @override
  Future<RaceParticipant?> getRaceParticipantByBib(
      int raceId, String bibNumber) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT rp.race_id, rp.runner_id, rp.team_id
      FROM race_participants rp
      JOIN runners r ON r.runner_id = rp.runner_id
      WHERE rp.race_id = ? AND r.bib_number = ?
      LIMIT 1
    ''', [raceId, bibNumber]);
    return rows.isNotEmpty ? RaceParticipant.fromMap(rows.first) : null;
  }

  @override
  Future<List<RaceParticipant>> getRaceParticipantsByBibs(
      int raceId, List<String> bibNumbers) async {
    final results = <RaceParticipant>[];
    for (final bib in bibNumbers) {
      final participant = await getRaceParticipantByBib(raceId, bib);
      if (participant != null) results.add(participant);
    }
    return results;
  }

  @override
  Future<List<RaceParticipant>> searchRaceParticipants(int raceId, String query,
      [String searchParameter = 'all']) async {
    final db = await _db;
    String whereClause;
    List<dynamic> whereArgs = [raceId];

    if (searchParameter == 'all') {
      whereClause =
          'rp.race_id = ? AND (r.name LIKE ? OR r.bib_number LIKE ? OR r.grade LIKE ? OR t.name LIKE ?)';
      whereArgs.addAll(['%$query%', '%$query%', '%$query%', '%$query%']);
    } else if (searchParameter == 'team_name') {
      whereClause = 'rp.race_id = ? AND t.name LIKE ?';
      whereArgs.add('%$query%');
    } else {
      whereClause = 'rp.race_id = ? AND r.$searchParameter LIKE ?';
      whereArgs.add('%$query%');
    }

    final rows = await db.rawQuery('''
      SELECT rp.race_id, rp.runner_id, rp.team_id
      FROM race_participants rp
      JOIN runners r ON r.runner_id = rp.runner_id
      JOIN teams t ON rp.team_id = t.team_id
      WHERE $whereClause
      ORDER BY r.bib_number
    ''', whereArgs);

    return rows.map((m) => RaceParticipant.fromMap(m)).toList();
  }

  // ============================================================================
  // FLOW STATE
  // ============================================================================

  @override
  Future<String> getRaceFlowState(int raceId) async {
    final race = await getRace(raceId);
    return race?.flowState ?? 'pre_race';
  }

  @override
  Future<void> updateRaceFlowState(int raceId, String flowState) async {
    await updateRace(Race(raceId: raceId, flowState: flowState));
  }

  // ============================================================================
  // CONVENIENCE
  // ============================================================================

  @override
  Future<void> updateRaceParticipantTeam({
    required int raceId,
    required int runnerId,
    required int newTeamId,
  }) async {
    final db = await _db;
    await db.update(
      'race_participants',
      {
        'team_id': newTeamId,
        'updated_at': DateTime.now().toIso8601String(),
        'is_dirty': 1,
      },
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceId, runnerId],
    );
  }

  @override
  Future<void> updateRunnerWithTeams({
    required Runner runner,
    int? newTeamId,
    int? raceIdForTeamUpdate,
  }) async {
    await _runnerRepo.updateRunner(runner);
    if (newTeamId != null) {
      await _runnerRepo.setRunnerTeam(runner.runnerId!, newTeamId);
      if (raceIdForTeamUpdate != null) {
        await updateRaceParticipantTeam(
          raceId: raceIdForTeamUpdate,
          runnerId: runner.runnerId!,
          newTeamId: newTeamId,
        );
      }
    }
  }
}
