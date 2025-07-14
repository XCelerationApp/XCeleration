import '../models/database/race_result.dart';
import '../models/database/team.dart';
import '../models/database/master_race.dart';

/// Service for calculating and processing race results
class RaceResultsService {
  /// Calculate team standings from race results
  static List<TeamStanding> calculateTeamStandings(
    List<RaceResult> results,
    List<Team> teams,
  ) {
    final standings = <TeamStanding>[];

    for (final team in teams) {
      final teamResults = results
          .where((result) => result.team?.teamId == team.teamId)
          .where((result) => result.place != null)
          .toList();

      if (teamResults.isNotEmpty) {
        // Sort by place
        teamResults.sort((a, b) => a.place!.compareTo(b.place!));

        // Take top 5 for scoring (standard cross country scoring)
        final scoringRunners = teamResults.take(5).toList();

        // Calculate team score (sum of places)
        final score =
            scoringRunners.fold<int>(0, (sum, result) => sum + result.place!);

        // Calculate split between 1st and 5th scorer
        Duration? split;
        if (scoringRunners.length >= 2) {
          final firstTime = scoringRunners.first.finishTime;
          final lastTime = scoringRunners.last.finishTime;
          if (firstTime != null && lastTime != null) {
            split = lastTime - firstTime;
          }
        }

        standings.add(TeamStanding(
          team: team,
          score: score,
          scoringRunners: scoringRunners,
          allRunners: teamResults,
          split: split,
        ));
      }
    }

    // Sort by score (lower is better)
    standings.sort((a, b) => a.score.compareTo(b.score));

    // Assign places
    for (int i = 0; i < standings.length; i++) {
      standings[i] = standings[i].copyWith(place: i + 1);
    }

    return standings;
  }

  /// Calculate individual results with places assigned
  static List<RaceResult> calculateIndividualResults(List<RaceResult> results) {
    // Filter out results without finish times
    final finishedResults =
        results.where((result) => result.finishTime != null).toList();

    // Sort by finish time
    finishedResults.sort((a, b) => a.finishTime!.compareTo(b.finishTime!));

    // Assign places
    final updatedResults = <RaceResult>[];
    for (int i = 0; i < finishedResults.length; i++) {
      updatedResults.add(finishedResults[i].copyWith(place: i + 1));
    }

    // Add back results without finish times
    final unfinishedResults =
        results.where((result) => result.finishTime == null).toList();

    updatedResults.addAll(unfinishedResults);

    return updatedResults;
  }

  /// Get results filtered by team
  static List<RaceResult> getResultsByTeam(
    List<RaceResult> results,
    Team team,
  ) {
    return results
        .where((result) => result.team?.teamId == team.teamId)
        .toList();
  }

  /// Get top performers across all teams
  static List<RaceResult> getTopPerformers(
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
  static Duration? calculateTeamAverageTime(List<RaceResult> teamResults) {
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

  /// Get grade-specific results
  static List<RaceResult> getResultsByGrade(
    List<RaceResult> results,
    int grade,
  ) {
    return results.where((result) => result.runner?.grade == grade).toList();
  }

  /// Calculate grade-specific standings
  static List<RaceResult> calculateGradeStandings(
    List<RaceResult> results,
    int grade,
  ) {
    final gradeResults = getResultsByGrade(results, grade);
    return calculateIndividualResults(gradeResults);
  }
}
