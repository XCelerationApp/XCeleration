import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';
import '../repositories/database_connection_provider.dart';
import '../repositories/i_database_connection_provider.dart';
import '../repositories/i_race_repository.dart';
import '../repositories/i_results_repository.dart';
import '../repositories/i_runner_repository.dart';
import '../repositories/i_team_repository.dart';
import '../repositories/race_repository.dart';
import '../repositories/results_repository.dart';
import '../repositories/runner_repository.dart';
import '../repositories/team_repository.dart';
import 'i_database_helper.dart';

/// Thin backward-compatibility shim.
///
/// New code must inject the appropriate repository interface directly:
/// - [IRunnerRepository] for runner and roster operations
/// - [ITeamRepository] for team operations
/// - [IRaceRepository] for race, participant, and flow-state operations
/// - [IResultsRepository] for race results
/// - [IDatabaseConnectionProvider] for raw connection access (e.g. SyncService)
///
/// This shim exists only to ease migration. Do not add new callers — inject
/// the repository or connection provider instead.
class DatabaseHelper implements IDatabaseHelper {
  final IDatabaseConnectionProvider _connProvider;
  final IRunnerRepository _runners;
  final ITeamRepository _teams;
  final IRaceRepository _races;
  final IResultsRepository _results;

  DatabaseHelper({
    IDatabaseConnectionProvider? connProvider,
    IRunnerRepository? runnerRepo,
    ITeamRepository? teamRepo,
    IRaceRepository? raceRepo,
    IResultsRepository? resultsRepo,
  })  : _connProvider = connProvider ?? DatabaseConnectionProvider(),
        _runners = runnerRepo ?? _defaultRunnerRepo(connProvider),
        _teams = teamRepo ?? _defaultTeamRepo(connProvider),
        _races = raceRepo ?? _defaultRaceRepo(connProvider, runnerRepo),
        _results = resultsRepo ?? _defaultResultsRepo(connProvider);

  final _writesController = StreamController<void>.broadcast();

  /// Emits a void event after every local write so listeners can react
  /// (e.g. debounce-trigger a sync) without polling.
  @override
  Stream<void> get writes => _writesController.stream;

  void _notifyWrite() {
    if (!_writesController.isClosed) _writesController.add(null);
  }

  static IRunnerRepository _defaultRunnerRepo(
      IDatabaseConnectionProvider? conn) {
    final c = conn ?? DatabaseConnectionProvider();
    return RunnerRepository(conn: c);
  }

  static ITeamRepository _defaultTeamRepo(IDatabaseConnectionProvider? conn) {
    final c = conn ?? DatabaseConnectionProvider();
    return TeamRepository(conn: c);
  }

  static IRaceRepository _defaultRaceRepo(
      IDatabaseConnectionProvider? conn, IRunnerRepository? runnerRepo) {
    final c = conn ?? DatabaseConnectionProvider();
    final r = runnerRepo ?? RunnerRepository(conn: c);
    return RaceRepository(conn: c, runnerRepo: r);
  }

  static IResultsRepository _defaultResultsRepo(
      IDatabaseConnectionProvider? conn) {
    final c = conn ?? DatabaseConnectionProvider();
    return ResultsRepository(conn: c);
  }

  // ============================================================================
  // CONNECTION
  // ============================================================================

  @override
  Future<Database> get databaseConn => _connProvider.database;

  // ============================================================================
  // RUNNERS
  // ============================================================================

  @override
  Future<int> createRunner(Runner runner) async {
    final id = await _runners.createRunner(runner);
    _notifyWrite();
    return id;
  }

  @override
  Future<Runner?> getRunner(int runnerId) => _runners.getRunner(runnerId);

  @override
  Future<Runner?> getRunnerByBib(String bibNumber) =>
      _runners.getRunnerByBib(bibNumber);

  @override
  Future<List<Runner>> getAllRunners() => _runners.getAllRunners();

  @override
  Future<List<Runner>> searchRunners(String query) =>
      _runners.searchRunners(query);

  @override
  Future<void> updateRunner(Runner runner) async {
    await _runners.updateRunner(runner);
    _notifyWrite();
  }

  @override
  Future<void> removeRunner(int runnerId) async {
    await _runners.removeRunner(runnerId);
    _notifyWrite();
  }

  @override
  Future<void> deleteRunnerEverywhere(int runnerId) async {
    await _runners.deleteRunnerEverywhere(runnerId);
    _notifyWrite();
  }

  @override
  Future<List<Runner>> getRunnersByBibAll(String bib) =>
      _runners.getRunnersByBibAll(bib);

  // ============================================================================
  // TEAM ROSTERS
  // ============================================================================

  @override
  Future<void> addRunnerToTeam(int teamId, int runnerId) async {
    await _runners.addRunnerToTeam(teamId, runnerId);
    _notifyWrite();
  }

  @override
  Future<void> removeRunnerFromTeam(int teamId, int runnerId) async {
    await _runners.removeRunnerFromTeam(teamId, runnerId);
    _notifyWrite();
  }

  @override
  Future<void> setRunnerTeam(int runnerId, int newTeamId) async {
    await _runners.setRunnerTeam(runnerId, newTeamId);
    _notifyWrite();
  }

  @override
  Future<Runner?> getTeamRunner(int teamId, int runnerId) =>
      _runners.getTeamRunner(teamId, runnerId);

  @override
  Future<List<Runner>> getTeamRunners(int teamId) =>
      _runners.getTeamRunners(teamId);

  @override
  Future<List<Team>> getRunnerTeams(int runnerId) =>
      _runners.getRunnerTeams(runnerId);

  // ============================================================================
  // TEAMS
  // ============================================================================

  @override
  Future<int> createTeam(Team team) async {
    final id = await _teams.createTeam(team);
    _notifyWrite();
    return id;
  }

  @override
  Future<Team?> getTeam(int teamId) => _teams.getTeam(teamId);

  @override
  Future<Team?> getTeamByName(String name) => _teams.getTeamByName(name);

  @override
  Future<List<Team>> getAllTeams() => _teams.getAllTeams();

  @override
  Future<List<Team>> searchTeams(String query) => _teams.searchTeams(query);

  @override
  Future<void> updateTeam(Team team) async {
    await _teams.updateTeam(team);
    _notifyWrite();
  }

  @override
  Future<void> deleteTeam(int teamId) async {
    await _teams.deleteTeam(teamId);
    _notifyWrite();
  }

  // ============================================================================
  // RACES
  // ============================================================================

  @override
  Future<int> createRace(Race race) async {
    final id = await _races.createRace(race);
    _notifyWrite();
    return id;
  }

  @override
  Future<Race?> getRace(int raceId) => _races.getRace(raceId);

  @override
  Future<List<Race>> getAllRaces() => _races.getAllRaces();

  @override
  Future<void> updateRace(Race race) async {
    await _races.updateRace(race);
    _notifyWrite();
  }

  @override
  Future<void> deleteRace(int raceId) async {
    await _races.deleteRace(raceId);
    _notifyWrite();
  }

  // ============================================================================
  // RACE TEAM PARTICIPATION
  // ============================================================================

  @override
  Future<void> addTeamParticipantToRace(TeamParticipant teamParticipant) async {
    await _races.addTeamParticipantToRace(teamParticipant);
    _notifyWrite();
  }

  @override
  Future<void> removeTeamParticipantFromRace(
      TeamParticipant teamParticipant) async {
    await _races.removeTeamParticipantFromRace(teamParticipant);
    _notifyWrite();
  }

  @override
  Future<Team?> getRaceTeamParticipant(TeamParticipant teamParticipant) =>
      _races.getRaceTeamParticipant(teamParticipant);

  @override
  Future<List<Team>> getRaceTeams(int raceId) => _races.getRaceTeams(raceId);

  // ============================================================================
  // RACE PARTICIPANTS
  // ============================================================================

  @override
  Future<void> addRaceParticipant(RaceParticipant raceParticipant) async {
    await _races.addRaceParticipant(raceParticipant);
    _notifyWrite();
  }

  @override
  Future<void> updateRaceParticipant(RaceParticipant raceParticipant) async {
    await _races.updateRaceParticipant(raceParticipant);
    _notifyWrite();
  }

  @override
  Future<void> removeRaceParticipant(RaceParticipant raceParticipant) async {
    await _races.removeRaceParticipant(raceParticipant);
    _notifyWrite();
  }

  @override
  Future<RaceParticipant?> getRaceParticipant(
          RaceParticipant raceParticipant) =>
      _races.getRaceParticipant(raceParticipant);

  @override
  Future<List<RaceParticipant>> getRaceParticipants(int raceId) =>
      _races.getRaceParticipants(raceId);

  @override
  Future<RaceParticipant?> getRaceParticipantByBib(
          int raceId, String bibNumber) =>
      _races.getRaceParticipantByBib(raceId, bibNumber);

  @override
  Future<List<RaceParticipant>> getRaceParticipantsByBibs(
          int raceId, List<String> bibNumbers) =>
      _races.getRaceParticipantsByBibs(raceId, bibNumbers);

  @override
  Future<List<RaceParticipant>> searchRaceParticipants(int raceId, String query,
          [String searchParameter = 'all']) =>
      _races.searchRaceParticipants(raceId, query, searchParameter);

  // ============================================================================
  // RACE RESULTS
  // ============================================================================

  @override
  Future<void> saveRaceResults(int raceId, List<RaceResult> results) async {
    await _results.saveRaceResults(raceId, results);
    _notifyWrite();
  }

  @override
  Future<void> addRaceResult(RaceResult result) async {
    await _results.addRaceResult(result);
    _notifyWrite();
  }

  @override
  Future<RaceResult?> getRaceResult(RaceResult raceResult) =>
      _results.getRaceResult(raceResult);

  @override
  Future<List<RaceResult>> getRaceResults(int raceId) =>
      _results.getRaceResults(raceId);

  @override
  Future<void> updateRaceResult(RaceResult raceResult) async {
    await _results.updateRaceResult(raceResult);
    _notifyWrite();
  }

  @override
  Future<void> deleteRaceResult(RaceResult raceResult) async {
    await _results.deleteRaceResult(raceResult);
    _notifyWrite();
  }

  // ============================================================================
  // CONVENIENCE
  // ============================================================================

  @override
  Future<String> getRaceFlowState(int raceId) =>
      _races.getRaceFlowState(raceId);

  @override
  Future<void> updateRaceFlowState(int raceId, String flowState) async {
    await _races.updateRaceFlowState(raceId, flowState);
    _notifyWrite();
  }

  @override
  Future<void> updateRaceParticipantTeam({
    required int raceId,
    required int runnerId,
    required int newTeamId,
  }) async {
    await _races.updateRaceParticipantTeam(
        raceId: raceId, runnerId: runnerId, newTeamId: newTeamId);
    _notifyWrite();
  }

  @override
  Future<void> updateRunnerWithTeams({
    required Runner runner,
    int? newTeamId,
    int? raceIdForTeamUpdate,
  }) async {
    await _races.updateRunnerWithTeams(
        runner: runner,
        newTeamId: newTeamId,
        raceIdForTeamUpdate: raceIdForTeamUpdate);
    _notifyWrite();
  }

  @override
  Future<Map<String, List<dynamic>>> quickSearch(String query) async {
    return {
      'runners': await _runners.searchRunners(query),
      'teams': await _teams.searchTeams(query),
    };
  }

  @override
  Future<String> getRaceState(int raceId) async {
    final raceResults = await _results.getRaceResults(raceId);
    return raceResults.isEmpty ? 'in_progress' : 'finished';
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  @override
  Future<void> clearAllData() async {
    final db = await _connProvider.database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_participants');
      await txn.delete('race_team_participation');
      await txn.delete('team_rosters');
      await txn.delete('teams');
      await txn.delete('runners');
      await txn.delete('races');
    });
    _notifyWrite();
  }

  @override
  Future<void> clearRaceData(int raceId) async {
    final db = await _connProvider.database;
    await db.transaction((txn) async {
      await txn
          .delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_participants',
          where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_team_participation',
          where: 'race_id = ?', whereArgs: [raceId]);
    });
    _notifyWrite();
  }

  @override
  Future<void> deleteAllRaces() async {
    final db = await _connProvider.database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_participants');
      await txn.delete('race_team_participation');
      await txn.delete('races');
    });
    _notifyWrite();
  }

  @override
  Future<void> deleteAllRaceRunners(int raceId) => clearRaceData(raceId);

  @override
  Future<void> deleteDatabase() => _connProvider.deleteDatabase();

  @override
  Future<void> close() => _connProvider.close();
}
