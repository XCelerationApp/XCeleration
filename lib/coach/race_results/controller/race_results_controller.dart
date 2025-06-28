import '../model/results_record.dart';
import '../model/team_record.dart';
import 'package:collection/collection.dart';
import 'package:xceleration/core/utils/database_helper.dart';

class RaceResultsController {
  final int raceId;
  final DatabaseHelper dbHelper;
  bool isLoading = true;
  String _raceName = 'Race Results';
  List<ResultsRecord> individualResults = [];
  List<TeamRecord> overallTeamResults = [];
  List<List<TeamRecord>>? headToHeadTeamResults;

  String get raceName => _raceName;

  RaceResultsController({
    required this.raceId,
    required this.dbHelper,
  }) {
    _calculateResults();
  }

  Future<void> _calculateResults() async {
    // Get race name from database
    try {
      final race = await dbHelper.getRaceById(raceId);
      if (race != null) {
        _raceName = race.raceName;
      } else {
        _raceName = 'Race Results';
      }
    } catch (e) {
      _raceName = 'Race Results';
    }

    // Get race results from database
    final List<ResultsRecord> results = await dbHelper.getRaceResults(raceId);

    if (results.isEmpty) {
      isLoading = false;
      return;
    }

    sortRunners(results);
    updateResultsPlaces(results);
    // DEEP COPY: Create completely independent copies for individual results
    individualResults = results.map((r) => ResultsRecord.copy(r)).toList();

    // Calculate teams from the original results (don't reuse individualResults to avoid cross-contamination)
    // Using original results ensures team calculations don't affect individual results
    final List<TeamRecord> teamResults = _calculateTeamResults(results);

    sortAndPlaceTeams(teamResults);

    // DEEP COPY: Create completely independent copies for team results
    overallTeamResults = teamResults.map((r) => TeamRecord.from(r)).toList();

    final List<TeamRecord> scoringTeams =
        teamResults.where((r) => r.score != 0).toList();

    if (scoringTeams.length > 3 || scoringTeams.length < 2) {
      isLoading = false;
      return;
    }
    // Calculate head-to-head matchups
    final List<List<TeamRecord>> headToHeadResults = [];
    for (var i = 0; i < scoringTeams.length; i++) {
      for (var j = i + 1; j < scoringTeams.length; j++) {
        // DEEP COPY: Create independent copies for each head-to-head matchup
        final teamA = TeamRecord.from(scoringTeams[i]);
        final teamB = TeamRecord.from(scoringTeams[j]);

        // Combine and sort runners for this specific matchup
        // These are already deep copies from TeamRecord.from
        final filteredRunners = [...teamA.topSeven, ...teamB.topSeven];
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

  List<TeamRecord> _calculateTeamResults(List<ResultsRecord> allResults) {
    final teams = _getTeamsFromResults(allResults);
    final teamCopy = teams.map((r) => TeamRecord.from(r)).toList();
    final scoringRunners = teamCopy
        .where((r) => r.score != 0)
        .map((r) => r.topSeven)
        .expand((r) => r)
        .toList();
    updateResultsPlaces(scoringRunners);
    final scoredTeams = _getTeamsFromResults(allResults);
    for (var i = 0; i < teams.length; i++) {
      teams[i].score = scoredTeams[i].score;
      teams[i].place = scoredTeams[i].place;
    }
    return teams;
  }

  List<TeamRecord> _getTeamsFromResults(List<ResultsRecord> results) {
    final List<TeamRecord> teams = [];
    for (var team in groupBy(results, (result) => result.school).entries) {
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

  void sortRunners(List<ResultsRecord> results) {
    results.sort((a, b) => a.finishTime.compareTo(b.finishTime));
  }

  void sortAndPlaceTeams(List<TeamRecord> teams) {
    teams.sort((a, b) {
      if (a.score == 0 && b.score == 0) return 0;
      if (a.score == 0) return 1;
      if (b.score == 0) return -1;
      return a.score - b.score;
    });
    for (int i = 0; i < teams.length; i++) {
      teams[i].place = i + 1;
    }
  }
}
