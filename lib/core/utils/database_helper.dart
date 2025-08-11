import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/database/base_models.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'local_schema.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _initializedDatabase;

  DatabaseHelper._init();

  Future<Database> get _database async {
    if (_initializedDatabase != null) return _initializedDatabase!;
    _initializedDatabase = await _initDB('races.db');
    return _initializedDatabase!;
  }

  // Expose a public connection getter for services like SyncService
  Future<Database> get databaseConn async => await _database;

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Execute centralized schema
    for (final stmt in splitSqlStatements(localSchemaSql)) {
      await db.execute(stmt);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ============================================================================
  // CORE ENTITY OPERATIONS
  // ============================================================================

  // --- RUNNERS ---
  Future<int> createRunner(Runner runner) async {
    if (!runner.isValid) {
      throw Exception('Runner is not valid');
    }
    if (await getRunnerByBib(runner.bibNumber!) != null) {
      throw Exception(
          'Runner with bib number ${runner.bibNumber} already exists');
    }
    final db = await _database;
    final result = await db.insert('runners', {
      'name': runner.name,
      'bib_number': runner.bibNumber,
      'grade': runner.grade,
      'is_dirty': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return result;
  }

  Future<Runner?> getRunner(int runnerId) async {
    final db = await _database;
    final results = await db.query(
      'runners',
      where: 'runner_id = ?',
      whereArgs: [runnerId],
    );
    return results.isNotEmpty ? Runner.fromMap(results.first) : null;
  }

  Future<Runner?> getRunnerByBib(String bibNumber) async {
    final db = await _database;
    final results = await db.query(
      'runners',
      where: 'bib_number = ?',
      whereArgs: [bibNumber],
    );
    return results.isNotEmpty ? Runner.fromMap(results.first) : null;
  }

  Future<List<Runner>> getAllRunners() async {
    final db = await _database;
    final results = await db.query('runners', orderBy: 'name');
    return results.map((map) => Runner.fromMap(map)).toList();
  }

  Future<List<Runner>> searchRunners(String query) async {
    final db = await _database;
    final results = await db.query(
      'runners',
      where: 'name LIKE ? OR bib_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return results.map((map) => Runner.fromMap(map)).toList();
  }

  Future<void> updateRunner(Runner runner) async {
    if (runner.runnerId == null) {
      throw Exception('Runner id is required');
    }
    if (!runner.isValid) {
      throw Exception('Runner is not valid');
    }
    final db = await _database;
    final map = runner.toMap();
    map['is_dirty'] = 1;
    await db.update('runners', map,
        where: 'runner_id = ?', whereArgs: [runner.runnerId]);
  }

  Future<void> removeRunner(int runnerId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    final db = await _database;
    await db.delete('runners', where: 'runner_id = ?', whereArgs: [runnerId]);
  }

  // --- TEAMS ---
  Future<int> createTeam(Team team) async {
    if (!team.isValid) {
      throw Exception('Team is not valid');
    }
    if (await getTeamByName(team.name!) != null) {
      throw Exception('Team with name ${team.name} already exists');
    }
    final db = await _database;
    return await db.insert('teams', {
      'name': team.name,
      'abbreviation':
          team.abbreviation ?? Team.generateAbbreviation(team.name!),
      // Store color as ARGB int; avoid passing a MaterialColor/Color object
      'color': team.color?.toARGB32() ?? 0,
      'is_dirty': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Team?> getTeam(int teamId) async {
    final db = await _database;
    final results =
        await db.query('teams', where: 'team_id = ?', whereArgs: [teamId]);
    return results.isNotEmpty ? Team.fromMap(results.first) : null;
  }

  Future<Team?> getTeamByName(String name) async {
    final db = await _database;
    final results = await db.query(
      'teams',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return results.isNotEmpty ? Team.fromMap(results.first) : null;
  }

  Future<List<Team>> getAllTeams() async {
    final db = await _database;
    final results = await db.query('teams', orderBy: 'name');
    return results.map((map) => Team.fromMap(map)).toList();
  }

  Future<List<Team>> searchTeams(String query) async {
    final db = await _database;
    final results = await db.query(
      'teams',
      where: 'name LIKE ? OR abbreviation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return results.map((map) => Team.fromMap(map)).toList();
  }

  Future<void> updateTeam(Team team) async {
    if (!team.isValid) {
      throw Exception('Team is not valid');
    }
    if (await getTeam(team.teamId!) == null) {
      throw Exception('Team with id ${team.teamId} not found');
    }
    final db = await _database;
    final updates = <String, dynamic>{};
    if (team.name != null) updates['name'] = team.name;
    if (team.abbreviation != null) updates['abbreviation'] = team.abbreviation;
    if (team.color != null) updates['color'] = team.color!.toARGB32();

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      updates['is_dirty'] = 1;
      await db.update('teams', updates,
          where: 'team_id = ?', whereArgs: [team.teamId]);
    }
  }

  Future<void> deleteTeam(int teamId) async {
    if (await getTeam(teamId) == null) {
      throw Exception('Team with id $teamId not found');
    }
    final db = await _database;
    await db.delete('teams', where: 'team_id = ?', whereArgs: [teamId]);
  }

  // --- RACES ---
  Future<int> createRace(Race race) async {
    if (!race.isValid) {
      throw Exception('Race is not valid');
    }
    final db = await _database;
    final map = race.toMap();
    map['is_dirty'] = 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('races', map);
  }

  Future<Race?> getRace(int raceId) async {
    final db = await _database;
    final results =
        await db.query('races', where: 'race_id = ?', whereArgs: [raceId]);
    return results.isNotEmpty ? Race.fromJson(results.first) : null;
  }

  Future<List<Race>> getAllRaces() async {
    final db = await _database;
    final results = await db.query('races', orderBy: 'race_date DESC');
    return results.map((map) => Race.fromJson(map)).toList();
  }

  Future<void> updateRace(Race race) async {
    if (race.raceId == null) {
      throw Exception('Race id is required');
    }
    if (!race.isValid) {
      throw Exception('Race is not valid');
    }
    if (await getRace(race.raceId!) == null) {
      throw Exception('Race with id ${race.raceId} not found');
    }
    final db = await _database;
    final rmap = race.toMap();
    rmap['is_dirty'] = 1;
    await db
        .update('races', rmap, where: 'race_id = ?', whereArgs: [race.raceId]);
  }

  Future<void> deleteRace(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _database;
    await db.delete('races', where: 'race_id = ?', whereArgs: [raceId]);
  }

  // ============================================================================
  // RELATIONSHIP OPERATIONS
  // ============================================================================

  // --- TEAM ROSTERS ---
  Future<void> addRunnerToTeam(int teamId, int runnerId) async {
    // If already linked, do nothing
    if (await getTeamRunner(teamId, runnerId) != null) {
      return;
    }
    final db = await _database;
    await db.insert(
      'team_rosters',
      {'team_id': teamId, 'runner_id': runnerId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeRunnerFromTeam(int teamId, int runnerId) async {
    if (await getTeamRunner(teamId, runnerId) == null) {
      throw Exception('Runner $runnerId not in team $teamId');
    }
    final db = await _database;
    await db.delete(
      'team_rosters',
      where: 'team_id = ? AND runner_id = ?',
      whereArgs: [teamId, runnerId],
    );
  }

  /// Set a runner's team globally in team_rosters.
  /// Removes any existing roster entries for the runner, then inserts the new team mapping.
  Future<void> setRunnerTeam(int runnerId, int newTeamId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    if (await getTeam(newTeamId) == null) {
      throw Exception('Team with id $newTeamId not found');
    }
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('team_rosters',
          where: 'runner_id = ?', whereArgs: [runnerId]);
      await txn.insert(
          'team_rosters',
          {
            'team_id': newTeamId,
            'runner_id': runnerId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Update a race participant's team mapping within a race.
  Future<void> updateRaceParticipantTeam({
    required int raceId,
    required int runnerId,
    required int newTeamId,
  }) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    if (await getTeam(newTeamId) == null) {
      throw Exception('Team with id $newTeamId not found');
    }
    final db = await _database;
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

  /// Convenience: update runner core fields and optionally move to a new team
  /// and/or update the runner's team within a specific race.
  Future<void> updateRunnerWithTeams({
    required Runner runner,
    int? newTeamId,
    int? raceIdForTeamUpdate,
  }) async {
    await updateRunner(runner);
    if (newTeamId != null) {
      await setRunnerTeam(runner.runnerId!, newTeamId);
      if (raceIdForTeamUpdate != null) {
        await updateRaceParticipantTeam(
          raceId: raceIdForTeamUpdate,
          runnerId: runner.runnerId!,
          newTeamId: newTeamId,
        );
      }
    }
  }

  Future<Runner?> getTeamRunner(int teamId, int runnerId) async {
    if (await getTeam(teamId) == null) {
      throw Exception('Team with id $teamId not found');
    }
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT r.* FROM runners r
      JOIN team_rosters tr ON r.runner_id = tr.runner_id
      WHERE tr.team_id = ? AND tr.runner_id = ?
    ''', [teamId, runnerId]);
    return results.isNotEmpty ? Runner.fromMap(results.first) : null;
  }

  Future<List<Runner>> getTeamRunners(int teamId) async {
    if (await getTeam(teamId) == null) {
      throw Exception('Team with id $teamId not found');
    }
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT r.* FROM runners r
      JOIN team_rosters tr ON r.runner_id = tr.runner_id
      WHERE tr.team_id = ?
      ORDER BY r.name
    ''', [teamId]);
    return results.map((map) => Runner.fromMap(map)).toList();
  }

  Future<List<Team>> getRunnerTeams(int runnerId) async {
    if (await getRunner(runnerId) == null) {
      throw Exception('Runner with id $runnerId not found');
    }
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT t.* FROM teams t
      JOIN team_rosters tr ON t.team_id = tr.team_id
      WHERE tr.runner_id = ?
      ORDER BY t.name
    ''', [runnerId]);
    return results.map((map) => Team.fromMap(map)).toList();
  }

  // --- RACE PARTICIPATION ---
  Future<void> addTeamParticipantToRace(TeamParticipant teamParticipant) async {
    if (!teamParticipant.isValid) {
      throw Exception('TeamParticipant is not valid');
    }
    if (await getRaceTeamParticipant(teamParticipant) != null) {
      throw Exception(
          'Team ${teamParticipant.teamId} already in race ${teamParticipant.raceId}');
    }
    final db = await _database;
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

  Future<void> removeTeamParticipantFromRace(
      TeamParticipant teamParticipant) async {
    if (await getRaceTeamParticipant(teamParticipant) == null) {
      throw Exception(
          'Team ${teamParticipant.teamId} not in race ${teamParticipant.raceId}');
    }
    final db = await _database;
    await db.delete(
      'race_team_participation',
      where: 'race_id = ? AND team_id = ?',
      whereArgs: [teamParticipant.raceId!, teamParticipant.teamId!],
    );
  }

  Future<Team?> getRaceTeamParticipant(TeamParticipant teamParticipant) async {
    if (await getRace(teamParticipant.raceId!) == null) {
      throw Exception('Race with id ${teamParticipant.raceId} not found');
    }
    if (await getTeam(teamParticipant.teamId!) == null) {
      throw Exception('Team with id ${teamParticipant.teamId} not found');
    }
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT t.*, rtp.team_color_override 
      FROM teams t
      JOIN race_team_participation rtp ON t.team_id = rtp.team_id
      WHERE rtp.race_id = ? AND rtp.team_id = ?
    ''', [teamParticipant.raceId!, teamParticipant.teamId!]);
    return results.isNotEmpty
        ? Team.fromRaceParticipationMap(results.first)
        : null;
  }

  Future<List<Team>> getRaceTeams(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT t.*, rtp.team_color_override 
      FROM teams t
      JOIN race_team_participation rtp ON t.team_id = rtp.team_id
      WHERE rtp.race_id = ?
      ORDER BY t.name
    ''', [raceId]);
    return results.map((map) => Team.fromRaceParticipationMap(map)).toList();
  }

  Future<void> addRaceParticipant(RaceParticipant raceParticipant) async {
    if (!raceParticipant.isValid) {
      throw Exception('RaceParticipant is not valid');
    }
    if (await getRaceParticipant(raceParticipant) != null) {
      throw Exception(
          'Runner ${raceParticipant.runnerId} already in race ${raceParticipant.raceId}');
    }
    final db = await _database;
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

  Future<void> updateRaceParticipant(RaceParticipant raceParticipant) async {
    if (await getRaceParticipant(raceParticipant) == null) {
      throw Exception('RaceParticipant not found');
    }
    final db = await _database;
    final pmap = raceParticipant.toMap();
    pmap['is_dirty'] = 1;
    pmap['updated_at'] = DateTime.now().toIso8601String();
    await db.update('race_participants', pmap,
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!]);
  }

  Future<void> removeRaceParticipant(RaceParticipant raceParticipant) async {
    if (await getRaceParticipant(raceParticipant) == null) {
      throw Exception(
          'Runner ${raceParticipant.runnerId} not in race ${raceParticipant.raceId}');
    }
    final db = await _database;
    await db.delete(
      'race_participants',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!],
    );
  }

  Future<RaceParticipant?> getRaceParticipant(
      RaceParticipant raceParticipant) async {
    if (await getRace(raceParticipant.raceId!) == null) {
      throw Exception('Race with id ${raceParticipant.raceId} not found');
    }
    if (await getRunner(raceParticipant.runnerId!) == null) {
      throw Exception('Runner with id ${raceParticipant.runnerId} not found');
    }
    final db = await _database;
    final results = await db.query(
      'race_participants',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceParticipant.raceId!, raceParticipant.runnerId!],
    );
    return results.isNotEmpty ? RaceParticipant.fromMap(results.first) : null;
  }

  Future<List<RaceParticipant>> getRaceParticipants(int raceId) async {
    if (await getRace(raceId) == null) {
      throw Exception('Race with id $raceId not found');
    }
    final db = await _database;
    final results = await db.query(
      'race_participants',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'runner_id',
    );
    return results.map((map) => RaceParticipant.fromMap(map)).toList();
  }

  Future<RaceParticipant?> getRaceParticipantByBib(
      int raceId, String bibNumber) async {
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT rp.race_id, rp.runner_id, rp.team_id
      FROM race_participants rp
      JOIN runners r ON r.runner_id = rp.runner_id
      WHERE rp.race_id = ? AND r.bib_number = ?
      LIMIT 1
    ''', [raceId, bibNumber]);
    return results.isNotEmpty ? RaceParticipant.fromMap(results.first) : null;
  }

  Future<List<RaceParticipant>> getRaceParticipantsByBibs(
      int raceId, List<String> bibNumbers) async {
    final results = <RaceParticipant>[];
    for (final bibNumber in bibNumbers) {
      final runner = await getRaceParticipantByBib(raceId, bibNumber);
      if (runner != null) {
        results.add(runner);
      }
    }
    return results;
  }

  Future<List<RaceParticipant>> searchRaceParticipants(int raceId, String query,
      [String searchParameter = 'all']) async {
    final db = await _database;

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

    final results = await db.rawQuery('''
      SELECT rp.race_id, rp.runner_id, rp.team_id
      FROM race_participants rp
      JOIN runners r ON r.runner_id = rp.runner_id
      JOIN teams t ON rp.team_id = t.team_id
      WHERE $whereClause
      ORDER BY r.bib_number
    ''', whereArgs);

    return results.map((map) => RaceParticipant.fromMap(map)).toList();
  }

  // ============================================================================
  // RACE RESULTS OPERATIONS
  // ============================================================================

  Future<void> saveRaceResults(int raceId, List<RaceResult> results) async {
    // Validate all results before saving
    for (final result in results) {
      if (!result.isValid) {
        throw Exception('RaceResult is not valid: ${result.toString()}');
      }
    }

    final db = await _database;
    await db.transaction((txn) async {
      // Clear existing results
      await txn
          .delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);

      // Insert new results
      for (final result in results) {
        await txn.insert('race_results', result.toMap());
      }
    });
  }

  Future<void> addRaceResult(RaceResult result) async {
    if (await getRaceResult(result) != null) {
      throw Exception('RaceResult already exists');
    }
    final db = await _database;
    final rr = result.toMap();
    rr['is_dirty'] = 1;
    rr['updated_at'] = DateTime.now().toIso8601String();
    await db.insert('race_results', rr);
  }

  Future<RaceResult?> getRaceResult(RaceResult raceResult) async {
    if (!raceResult.isValid) {
      throw Exception('RaceResult is not valid');
    }
    final db = await _database;
    final results = await db.query(
      'race_results',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!],
    );
    return results.isNotEmpty ? RaceResult.fromMap(results.first) : null;
  }

  Future<List<RaceResult>> getRaceResults(int raceId) async {
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT 
        rr.runner_id,
        r.bib_number,
        r.name,
        t.name as team_name,
        r.grade,
        rr.place,
        rr.finish_time,
        rr.race_id
      FROM race_results rr
      JOIN runners r ON rr.runner_id = r.runner_id
      JOIN race_participants rp ON r.runner_id = rp.runner_id AND rr.race_id = rp.race_id
      JOIN teams t ON rp.team_id = t.team_id
      WHERE rr.race_id = ?
      ORDER BY rr.place
    ''', [raceId]);
    return results.map((map) => RaceResult.fromMap(map)).toList();
  }

  Future<void> updateRaceResult(RaceResult raceResult) async {
    if (!raceResult.isValid) {
      throw Exception('RaceResult is not valid');
    }
    if (await getRaceResult(raceResult) == null) {
      throw Exception(
          'Result for runner ${raceResult.runner?.runnerId} in race ${raceResult.raceId} not found');
    }
    final db = await _database;
    final rrmap = raceResult.toMap();
    rrmap['is_dirty'] = 1;
    await db.update('race_results', rrmap,
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!]);
  }

  Future<void> deleteRaceResult(RaceResult raceResult) async {
    if (raceResult.raceId == null || raceResult.runner?.runnerId == null) {
      throw Exception('Race or runner not given');
    }
    if (await getRaceResult(raceResult) == null) {
      throw Exception(
          'Result for runner ${raceResult.runner?.runnerId} in race ${raceResult.raceId} not found');
    }
    final db = await _database;
    await db.delete(
      'race_results',
      where: 'race_id = ? AND runner_id = ?',
      whereArgs: [raceResult.raceId!, raceResult.runner!.runnerId!],
    );
  }

  // ============================================================================
  // CONVENIENCE METHODS
  // ============================================================================

  /// Get race flow state
  Future<String> getRaceFlowState(int raceId) async {
    final race = await getRace(raceId);
    return race?.flowState ?? 'pre_race';
  }

  /// Update race flow state
  Future<void> updateRaceFlowState(int raceId, String flowState) async {
    await updateRace(Race(raceId: raceId, flowState: flowState));
  }

  /// Quick search across all entities
  Future<Map<String, List<dynamic>>> quickSearch(String query) async {
    final results = <String, List<dynamic>>{};

    results['runners'] = await searchRunners(query);
    results['teams'] = await searchTeams(query);

    return results;
  }

  /// Get race state
  Future<String> getRaceState(int raceId) async {
    final raceResults = await getRaceResults(raceId);
    return raceResults.isEmpty ? 'in_progress' : 'finished';
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Clear all data from _database
  Future<void> clearAllData() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_participants');
      await txn.delete('race_team_participation');
      await txn.delete('team_rosters');
      await txn.delete('teams');
      await txn.delete('runners');
      await txn.delete('races');
    });
  }

  /// Clear race-specific data
  Future<void> clearRaceData(int raceId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn
          .delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_participants',
          where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_team_participation',
          where: 'race_id = ?', whereArgs: [raceId]);
    });
  }

  /// Delete all races and related data
  Future<void> deleteAllRaces() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_participants');
      await txn.delete('race_team_participation');
      await txn.delete('races');
    });
  }

  /// Delete all race runners for a specific race
  Future<void> deleteAllRaceRunners(int raceId) async {
    await clearRaceData(raceId);
  }

  /// Delete the database file
  Future<void> deleteDatabase() async {
    Logger.d('Deleting database');
    final path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _initializedDatabase = null;
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _initializedDatabase = null;
  }
}
