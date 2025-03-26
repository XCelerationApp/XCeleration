import '../model/results_record.dart';
import '../model/team_record.dart';
import 'package:collection/collection.dart';
import 'package:xcelerate/utils/database_helper.dart';


class ResultsScreenController {
  final int raceId;
  bool isHeadToHead = false;
  bool isLoading = true;
  List<ResultsRecord> individualResults = [];
  List<TeamRecord> overallTeamResults = [];
  List<TeamRecord> individualTeamResults = [];
  List<List<TeamRecord>> headToHeadTeamResults = [];

  ResultsScreenController({
    required this.raceId,
  }) {
    _calculateResults();
  }


  Future<void> _calculateResults() async {
    final List<ResultsRecord> results = await DatabaseHelper.instance.getRaceResults(raceId);
    updateResultsPlaces(results);
    individualResults = List.from(results);

    final List<TeamRecord> teamResults = _calculateTeams(results);
    overallTeamResults = List.from(teamResults);
    sortAndPlaceTeams(overallTeamResults);

    final List<TeamRecord> individualTeamResultsCopy = List.from(teamResults);
    for (var team in individualTeamResultsCopy) {
      updateResultsPlaces(team.runners);
    }

    individualTeamResults = individualTeamResultsCopy;

    final List<List<TeamRecord>> headToHeadResults = [];
    for (var i = 0; i < teamResults.length; i++) {
      for (var j = i + 1; j < teamResults.length; j++) {
        final teamA = TeamRecord.from(teamResults[i]);
        final teamB = TeamRecord.from(teamResults[j]);
        final filteredRunners = [...teamA.runners, ...teamB.runners];
        filteredRunners.sort((a, b) => b.finishTime.compareTo(a.finishTime));
        updateResultsPlaces(filteredRunners);
        teamA.updateStats();
        teamB.updateStats();
        final matchup = [teamA, teamB];
        sortAndPlaceTeams(matchup);
        headToHeadResults.add(matchup);
      }
    }

    headToHeadTeamResults = headToHeadResults;
    isLoading = false;
  }

  List<TeamRecord> _calculateTeams(List<ResultsRecord> allResults) {
    final List<TeamRecord> teams = [];
    for (var team in groupBy(allResults, (result) => result.school).entries) {
      final teamRecord = TeamRecord(
        school: team.key,
        runners: team.value,
      );
      teams.add(teamRecord);
    }
    return teams;
  }

  void updateResultsPlaces(List<ResultsRecord> results) {
    for (int i = 0; i < results.length; i++) {
      results[i].place = i + 1;
    }
  }

  void sortAndPlaceTeams(List<TeamRecord> teams) {
    teams.sort((a, b) => b.score - a.score);
    for (int i = 0; i < teams.length; i++) {
      teams[i].place = i + 1;
    }
  }
}
  
