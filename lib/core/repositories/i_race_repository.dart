import '../../shared/models/database/base_models.dart';

abstract interface class IRaceRepository {
  // --- Race CRUD ---
  Future<int> createRace(Race race);
  Future<Race?> getRace(int raceId);
  Future<List<Race>> getAllRaces();
  Future<void> updateRace(Race race);
  Future<void> deleteRace(int raceId);

  // --- Race team participation ---
  Future<void> addTeamParticipantToRace(TeamParticipant teamParticipant);
  Future<void> removeTeamParticipantFromRace(TeamParticipant teamParticipant);
  Future<Team?> getRaceTeamParticipant(TeamParticipant teamParticipant);
  Future<List<Team>> getRaceTeams(int raceId);

  // --- Race participants ---
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

  // --- Flow state helpers ---
  Future<String> getRaceFlowState(int raceId);
  Future<void> updateRaceFlowState(int raceId, String flowState);

  // --- Convenience ---
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
}
