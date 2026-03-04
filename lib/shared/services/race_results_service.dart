import '../models/database/race_result.dart';
import '../models/database/team.dart';
import '../models/database/master_race.dart';
import '../../coach/race_results/model/team_record.dart';
import '../../coach/race_results/model/results_record.dart';
import '../../core/utils/logger.dart';
import '../../core/result.dart';
import '../../core/app_error.dart';
import 'i_race_results_service.dart';
import 'package:collection/collection.dart';

/// Service for calculating and processing race results
class RaceResultsService implements IRaceResultsService {
  const RaceResultsService();

  /// Calculate team results from race results
  List<TeamRecord> calculateTeamResults(List<RaceResult> allResults) {
    // Group results by team and create TeamRecord objects
    // Results should already be sorted by finish time from calculateIndividualResults
    final teams = _getTeamsFromResults(allResults);

    // Ensure runners within each team are sorted by their finish time
    for (final team in teams) {
      team.runners.sort((a, b) => a.compareTimeTo(b));
    }

    return teams;
  }

  /// Helper function to group results by team into TeamRecord objects
  List<TeamRecord> _getTeamsFromResults(List<RaceResult> results) {
    final List<TeamRecord> teams = [];
    for (var team in groupBy(results, (result) => result.team!).entries) {
      final teamRecord = TeamRecord(
        team: team.key,
        runners: team.value,
      );
      teams.add(teamRecord);
    }
    return teams;
  }

  /// Calculate individual results with places assigned
  List<RaceResult> calculateIndividualResults(List<RaceResult> results) {
    if (results.isEmpty) return [];

    _sortRunners(results);
    updateResultsPlaces(results);
    // Create deep copies to prevent reference issues
    return results.map((r) => RaceResult.copy(r)).toList();
  }

  /// Convert RaceResult objects to ResultsRecord objects for UI display
  List<ResultsRecord> convertToResultsRecords(List<RaceResult> raceResults,
      {double? raceDistance, String? distanceUnit}) {
    // Convert race distance to miles and compute pace/mi only
    double miles = 0.0;
    if (raceDistance != null && raceDistance > 0) {
      if (distanceUnit != null && distanceUnit.toLowerCase() == 'km') {
        miles = raceDistance * 0.621371;
      } else {
        miles = raceDistance;
      }
    }

    return raceResults.map((raceResult) {
      final finish = raceResult.finishTime ?? Duration.zero;
      Duration? pacePerMile;
      if (miles > 0 && finish.inMilliseconds > 0) {
        final paceMs = (finish.inMilliseconds / miles).round();
        pacePerMile = Duration(milliseconds: paceMs);
      }

      return ResultsRecord(
        place: raceResult.place ?? 0,
        name: raceResult.runner?.name ?? 'Unknown',
        team: raceResult.team?.name ?? 'Unknown',
        teamAbbreviation: raceResult.team?.abbreviation ?? 'N/A',
        grade: raceResult.runner?.grade ?? 0,
        bib: raceResult.runner?.bibNumber ?? '',
        raceId: raceResult.raceId ?? 0,
        runnerId: raceResult.runner?.runnerId ?? 0,
        finishTime: finish,
        pacePerMile: pacePerMile,
      );
    }).toList();
  }

  /// Calculate head-to-head matchups between teams
  List<List<TeamRecord>> calculateHeadToHeadResults(
      List<TeamRecord> teamResults) {
    final List<TeamRecord> scoringTeams =
        teamResults.where((r) => r.score != 0).toList();

    if (scoringTeams.length > 3 || scoringTeams.length < 2) {
      return [];
    }

    final List<List<TeamRecord>> headToHeadResults = [];
    for (var i = 0; i < scoringTeams.length; i++) {
      for (var j = i + 1; j < scoringTeams.length; j++) {
        // DEEP COPY: Create independent copies for each head-to-head matchup
        final teamA = TeamRecord.from(scoringTeams[i]);
        final teamB = TeamRecord.from(scoringTeams[j]);

        final matchup = [teamA, teamB];
        sortAndPlaceTeams(matchup);
        headToHeadResults.add(matchup);
      }
    }

    return headToHeadResults;
  }

  /// Update places for a list of results
  void updateResultsPlaces(List<RaceResult> results) {
    for (int i = 0; i < results.length; i++) {
      results[i].place = i + 1;
    }
  }

  /// Sort runners by their finish time
  void _sortRunners(List<RaceResult> results) {
    results.sort((a, b) => a.compareTimeTo(b));
  }

  /// Sort teams by score and assign places
  void sortAndPlaceTeams(List<TeamRecord> teams) {
    // Recompute places using ONLY teams with at least 5 runners
    final List<TeamRecord> eligibleTeams = [
      for (final team in teams)
        if (team.runners.length >= 5) team,
    ];

    final List<RaceResult> filteredRunners = [
      for (final team in eligibleTeams) ...team.topSeven,
    ];

    _sortRunners(filteredRunners);
    updateResultsPlaces(filteredRunners);

    // Update stats per team and handle incomplete teams
    for (final team in teams) {
      team.updateStats();
      if (team.runners.length < 5) {
        team.score = 0;
      }
    }

    // Place only eligible teams by score; incomplete teams go to the end with N/A
    final List<TeamRecord> incompleteTeams = [
      for (final team in teams)
        if (team.runners.length < 5) team,
    ];
    final List<TeamRecord> completeTeams = [
      for (final team in teams)
        if (team.runners.length >= 5) team,
    ];

    completeTeams.sort((a, b) => a.score.compareTo(b.score));

    // Assign places to complete teams first
    for (int i = 0; i < completeTeams.length; i++) {
      completeTeams[i].place = i + 1;
    }

    // Incomplete teams are placed after complete teams; score already set to 0 to show N/A in UI
    for (final team in incompleteTeams) {
      team.place = (completeTeams.length) + incompleteTeams.indexOf(team) + 1;
    }

    // Rebuild original list ordering to reflect new placements
    teams
      ..clear()
      ..addAll([...completeTeams, ...incompleteTeams]);
  }

  /// Complete race results calculation - main orchestrator function
  @override
  Future<Result<RaceResultsData>> calculateCompleteRaceResults(
      MasterRace masterRace) async {
    try {
      Logger.d('RaceResultsService: Starting calculateCompleteRaceResults');

      final resultsTitle = await RaceResultsData.getResultsTitle(masterRace);

      final race = await masterRace.race;
      final double? raceDistance = race.distance;
      final String? distanceUnit = race.distanceUnit;

      // Get race results from database
      final List<RaceResult> results = await masterRace.results;
      Logger.d('RaceResultsService: Got ${results.length} race results');

      if (results.isEmpty) {
        return Success(RaceResultsData(
          resultsTitle: resultsTitle,
          individualResults: <ResultsRecord>[],
          overallTeamResults: [],
          headToHeadTeamResults: [],
        ));
      }

      // Calculate individual results
      final raceResults = calculateIndividualResults(results);
      final individualResults = convertToResultsRecords(raceResults,
          raceDistance: raceDistance, distanceUnit: distanceUnit);

      // Calculate team results
      final teamResults = calculateTeamResults(raceResults);
      sortAndPlaceTeams(teamResults);

      // DEEP COPY: Create completely independent copies for team results
      final overallTeamResults =
          teamResults.map((r) => TeamRecord.from(r)).toList();

      // Calculate head-to-head matchups
      List<List<TeamRecord>> headToHeadTeamResults = [];
      if (teamResults.length >= 2 && teamResults.length <= 4) {
        headToHeadTeamResults = calculateHeadToHeadResults(teamResults);
      }

      return Success(RaceResultsData(
        resultsTitle: resultsTitle,
        individualResults: individualResults,
        overallTeamResults: overallTeamResults,
        headToHeadTeamResults: headToHeadTeamResults,
      ));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not calculate race results. Please try again.',
        originalException: e,
      ));
    }
  }

  /// Get results filtered by team
  List<RaceResult> getResultsByTeam(
    List<RaceResult> results,
    Team team,
  ) {
    return results
        .where((result) => result.team?.teamId == team.teamId)
        .toList();
  }

  /// Get top performers across all teams
  List<RaceResult> getTopPerformers(
    List<RaceResult> results, {
    int count = 10,
  }) {
    final finishedResults = results
        .where((result) => result.finishTime != null && result.place != null)
        .toList();

    finishedResults.sort((a, b) => a.place!.compareTo(b.place!));

    return finishedResults.take(count).toList();
  }

  /// Calculate average time for a team
  Duration? calculateTeamAverageTime(List<RaceResult> teamResults) {
    final finishedResults = teamResults
        .where((result) => result.finishTime != null)
        .take(5) // Top 5 runners
        .toList();

    if (finishedResults.isEmpty) return null;

    final totalMilliseconds = finishedResults.fold<int>(
      0,
      (sum, result) => sum + result.finishTime!.inMilliseconds,
    );

    final averageMilliseconds = totalMilliseconds ~/ finishedResults.length;
    return Duration(milliseconds: averageMilliseconds);
  }
}

/// Data class to hold complete race results
class RaceResultsData {
  final String resultsTitle;
  final List<ResultsRecord> individualResults;
  final List<TeamRecord> overallTeamResults;
  final List<List<TeamRecord>> headToHeadTeamResults;

  const RaceResultsData({
    required this.resultsTitle,
    required this.individualResults,
    required this.overallTeamResults,
    required this.headToHeadTeamResults,
  });

  static Future<String> getResultsTitle(MasterRace masterRace) async {
    final race = await masterRace.race;
    final raceName = race.raceName;
    final raceDate = race.raceDate;
    final shortDate =
        raceDate != null ? '${raceDate.month}/${raceDate.day}' : '';
    if (raceName == null) return '$shortDate Race Results';
    return '$raceName $shortDate Results';
  }
}
