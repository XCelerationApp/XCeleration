import '../../shared/models/database/base_models.dart';

abstract class IRunnerRepository {
  // --- CRUD ---
  Future<int> createRunner(Runner runner);
  Future<Runner?> getRunner(int runnerId);
  Future<Runner?> getRunnerByBib(String bibNumber);
  Future<List<Runner>> getAllRunners();
  Future<List<Runner>> searchRunners(String query);
  Future<void> updateRunner(Runner runner);
  Future<void> removeRunner(int runnerId);
  Future<void> deleteRunnerEverywhere(int runnerId);
  Future<List<Runner>> getRunnersByBibAll(String bib);

  // --- Team roster ---
  Future<void> addRunnerToTeam(int teamId, int runnerId);
  Future<void> removeRunnerFromTeam(int teamId, int runnerId);
  Future<void> setRunnerTeam(int runnerId, int newTeamId);
  Future<Runner?> getTeamRunner(int teamId, int runnerId);
  Future<List<Runner>> getTeamRunners(int teamId);
  Future<List<Team>> getRunnerTeams(int runnerId);
}
