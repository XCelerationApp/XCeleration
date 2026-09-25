import '../../shared/models/database/base_models.dart';

abstract interface class ITeamRepository {
  Future<int> createTeam(Team team);
  Future<Team?> getTeam(int teamId);
  Future<Team?> getTeamByName(String name);
  Future<List<Team>> getAllTeams();
  Future<List<Team>> searchTeams(String query);
  Future<void> updateTeam(Team team);
  Future<void> deleteTeam(int teamId);
}
