import 'package:flutter/foundation.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

abstract interface class IMasterRaceResolver {
  Future<List<Team>> get teams;
  Future<List<RaceRunner>> get raceRunners;
  Future<void> searchRaceRunners(String query);
  Future<Map<Team, List<RaceRunner>>> get filteredSearchResults;
  Future<Runner?> getRunnerByBib(String bibNumber);
  Future<int> createRunner(Runner runner);
  Future<void> addRunnerToTeam(int teamId, int runnerId);
  Future<void> addRaceParticipant(RaceParticipant raceParticipant);
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
