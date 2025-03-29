import '../model/results_record.dart';
import '../model/team_record.dart';
import 'package:collection/collection.dart';
import 'package:xcelerate/utils/database_helper.dart';

class RaceResultsController {
  final int raceId;
  bool isLoading = true;
  List<ResultsRecord> individualResults = [];
  List<TeamRecord> overallTeamResults = [];
  List<List<TeamRecord>>? headToHeadTeamResults;

  RaceResultsController({
    required this.raceId,
  }) {
    _calculateResults();
  }

  // Get top N runners from individual results
  List<ResultsRecord> getTopRunners(int count) {
    if (individualResults.isEmpty) return [];
    return individualResults.take(count).toList();
  }

  Future<void> _calculateResults() async {
    // Get race results from database
    final List<ResultsRecord> results = await DatabaseHelper.instance.getRaceResults(raceId);
    
    // DEEP COPY: Create completely independent copies for individual results
    individualResults = results.map((r) => ResultsRecord.copy(r)).toList();

    // Calculate teams from the original results (don't reuse individualResults to avoid cross-contamination)
    // Using original results ensures team calculations don't affect individual results
    final List<TeamRecord> teamResults = _calculateTeams(results);

    sortAndPlaceTeams(teamResults);

    // DEEP COPY: Create completely independent copies for overall team results
    overallTeamResults = teamResults.map((r) => TeamRecord.from(r)).toList();    
    if (teamResults.length > 3 || teamResults.length < 2) {
      isLoading = false;
      return;
    }
    // Calculate head-to-head matchups
    final List<List<TeamRecord>> headToHeadResults = [];
    for (var i = 0; i < teamResults.length; i++) {
      for (var j = i + 1; j < teamResults.length; j++) {
        // DEEP COPY: Create independent copies for each head-to-head matchup
        final teamA = TeamRecord.from(teamResults[i]);
        final teamB = TeamRecord.from(teamResults[j]);
        
        // Combine and sort runners for this specific matchup
        // These are already deep copies from TeamRecord.from
        final filteredRunners = [...teamA.runners, ...teamB.runners];
        filteredRunners.sort((a, b) => a.finishTime.compareTo(b.finishTime));
        updateResultsPlaces(filteredRunners);
        
        // Update stats based on the new places
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
