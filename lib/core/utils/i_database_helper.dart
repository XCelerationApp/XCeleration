import 'package:sqflite/sqflite.dart';
import '../../shared/models/database/base_models.dart';

abstract class IDatabaseHelper {
  // ============================================================================
  // CONNECTION
  // ============================================================================

  Future<Database> get databaseConn;

  // ============================================================================
  // CORE ENTITY OPERATIONS
  // ============================================================================

  // --- RUNNERS ---
  Future<int> createRunner(Runner runner);
  Future<Runner?> getRunner(int runnerId);
  Future<Runner?> getRunnerByBib(String bibNumber);
  Future<List<Runner>> getAllRunners();
  Future<List<Runner>> searchRunners(String query);
  Future<void> updateRunner(Runner runner);
  Future<void> removeRunner(int runnerId);

  // --- TEAMS ---
  Future<int> createTeam(Team team);
  Future<Team?> getTeam(int teamId);
  Future<Team?> getTeamByName(String name);
  Future<List<Team>> getAllTeams();
  Future<List<Team>> searchTeams(String query);
  Future<void> updateTeam(Team team);
  Future<void> deleteTeam(int teamId);

  // --- RACES ---
  Future<int> createRace(Race race);
  Future<Race?> getRace(int raceId);
  Future<List<Race>> getAllRaces();
  Future<void> updateRace(Race race);
  Future<void> deleteRace(int raceId);

  // ============================================================================
  // RELATIONSHIP OPERATIONS
  // ============================================================================

  // --- TEAM ROSTERS ---
  Future<void> addRunnerToTeam(int teamId, int runnerId);
  Future<void> removeRunnerFromTeam(int teamId, int runnerId);
  Future<void> setRunnerTeam(int runnerId, int newTeamId);
  Future<void> updateRaceParticipantTeam({
    required int raceId,
    required int runnerId,
    required int newTeamId,
  });
  Future<void> updateRunnerWithTeams({
    required Runner runner,
    int? newTeamId,
    int? raceIdForTeamUpdate,
  });
  Future<Runner?> getTeamRunner(int teamId, int runnerId);
  Future<List<Runner>> getTeamRunners(int teamId);
  Future<List<Team>> getRunnerTeams(int runnerId);

  // --- RACE PARTICIPATION ---
  Future<void> addTeamParticipantToRace(TeamParticipant teamParticipant);
  Future<void> removeTeamParticipantFromRace(TeamParticipant teamParticipant);
  Future<Team?> getRaceTeamParticipant(TeamParticipant teamParticipant);
  Future<List<Team>> getRaceTeams(int raceId);
  Future<void> addRaceParticipant(RaceParticipant raceParticipant);
  Future<void> updateRaceParticipant(RaceParticipant raceParticipant);
  Future<void> removeRaceParticipant(RaceParticipant raceParticipant);
  Future<RaceParticipant?> getRaceParticipant(RaceParticipant raceParticipant);
  Future<List<RaceParticipant>> getRaceParticipants(int raceId);
  Future<RaceParticipant?> getRaceParticipantByBib(
      int raceId, String bibNumber);
  Future<List<RaceParticipant>> getRaceParticipantsByBibs(
      int raceId, List<String> bibNumbers);
  Future<List<RaceParticipant>> searchRaceParticipants(int raceId, String query,
      [String searchParameter = 'all']);

  // ============================================================================
  // RACE RESULTS OPERATIONS
  // ============================================================================

  Future<void> saveRaceResults(int raceId, List<RaceResult> results);
  Future<void> addRaceResult(RaceResult result);
  Future<RaceResult?> getRaceResult(RaceResult raceResult);
  Future<List<RaceResult>> getRaceResults(int raceId);
  Future<void> updateRaceResult(RaceResult raceResult);
  Future<void> deleteRaceResult(RaceResult raceResult);

  // ============================================================================
  // CONVENIENCE METHODS
  // ============================================================================

  Future<String> getRaceFlowState(int raceId);
  Future<void> updateRaceFlowState(int raceId, String flowState);
  Future<Map<String, List<dynamic>>> quickSearch(String query);
  Future<String> getRaceState(int raceId);

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Future<void> clearAllData();
  Future<void> clearRaceData(int raceId);
  Future<void> deleteAllRaces();
  Future<void> deleteAllRaceRunners(int raceId);
  Future<void> deleteDatabase();
  Future<void> close();
  Future<void> deleteRunnerEverywhere(int runnerId);
  Future<List<Runner>> getRunnersByBibAll(String bib);
}
