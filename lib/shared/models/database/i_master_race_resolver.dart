import 'package:flutter/foundation.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';

abstract interface class IMasterRaceResolver {
  int get raceId;

  Future<List<Team>> get teams;
  Future<List<RaceRunner>> get raceRunners;
  Future<List<RaceParticipant>> get raceParticipants;
  Future<Map<Team, List<RaceRunner>>> get filteredSearchResults;

  Future<void> searchRaceRunners(String query, [String searchAttribute = 'all']);

  Future<Runner?> getRunnerByBib(String bibNumber);
  Future<int> createRunner(Runner runner);
  Future<void> addRunnerToTeam(int teamId, int runnerId);

  Future<Team?> getTeamByName(String teamName);
  Future<List<Team>> getOtherTeams();

  Future<void> addRaceParticipant(RaceParticipant raceParticipant);
  Future<void> addRaceParticipantsBulk(List<RaceParticipant> raceParticipants);
  Future<void> removeRaceParticipant(RaceParticipant raceParticipant);
  Future<void> updateRaceParticipant(RaceParticipant raceParticipant);
  Future<void> removeRaceRunner(RaceRunner raceRunner);

  Future<void> addTeamParticipant(TeamParticipant teamParticipant);
  Future<void> removeTeamFromRace(TeamParticipant teamParticipant);

  void invalidateCache();

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
