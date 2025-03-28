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
  
  // Track expanded states
  final Map<String, bool> expandedTeams = {};
  bool expandedIndividuals = false;

  ResultsScreenController({
    required this.raceId,
  }) {
    _calculateResults();
  }

  // Get top N runners from individual results
  List<ResultsRecord> getTopRunners(int count) {
    if (individualResults.isEmpty) return [];
    return individualResults.take(count).toList();
  }
  
  // Toggle expansion state for a team
  void toggleTeamExpansion(String teamName) {
    expandedTeams[teamName] = !(expandedTeams[teamName] ?? false);
  }
  
  // Toggle expansion state for individual results
  void toggleIndividualExpansion() {
    expandedIndividuals = !expandedIndividuals;
  }
  
  // Get race summary data
  Map<String, dynamic> getRaceSummary() {
    if (individualResults.isEmpty) {
      return {
        'totalRunners': 0,
        'totalTeams': 0,
        'fastestTime': '--:--',
        'averageTime': '--:--',
      };
    }
    
    final fastestRunner = individualResults.first;
    
    // Calculate average time in milliseconds
    int totalMs = 0;
    for (var runner in individualResults) {
      totalMs += runner.finishTime.inMilliseconds;
    }
    final avgTimeMs = totalMs ~/ individualResults.length;
    
    // Format average time
    final avgMinutes = (avgTimeMs ~/ 60000).toString().padLeft(2, '0');
    final avgSeconds = ((avgTimeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    
    return {
      'totalRunners': individualResults.length,
      'totalTeams': overallTeamResults.length,
      'fastestTime': fastestRunner.formattedFinishTime,
      'averageTime': '$avgMinutes:$avgSeconds',
    };
  }

  Future<void> _calculateResults() async {
    final List<ResultsRecord> results = await DatabaseHelper.instance.getRaceResults(raceId);
    // updateResultsPlaces(results);
    individualResults = List.from(results);

    final List<TeamRecord> teamResults = _calculateTeams(List.from(results));
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
        filteredRunners.sort((a, b) => a.finishTime.compareTo(b.finishTime));
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
    teams.sort((a, b) => a.score - b.score);
    for (int i = 0; i < teams.length; i++) {
      teams[i].place = i + 1;
    }
  }
}
