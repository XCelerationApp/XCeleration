import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/team.dart';

class TeamRecord {
  late int score;
  final Team team;
  late final List<RaceResult> scorers;
  late final List<RaceResult> nonScorers;
  final List<RaceResult> runners;
  int? place;
  late Duration split;
  late Duration avgTime;

  TeamRecord({
    required this.team,
    required this.runners,
    this.place,
  }) {
    nonScorers = runners;

    // Take top 5 runners for scoring, or all runners if less than 5
    scorers = runners.take(5).toList();
    updateStats();
  }

  List<RaceResult> get topSeven => runners.take(7).toList();

  factory TeamRecord.from(TeamRecord other) => TeamRecord(
        team: other.team,
        // Create deep copies of all runners to prevent reference issues
        runners: other.runners.map((r) => RaceResult.copy(r)).toList(),
        place: other.place,
      );

  void updateStats() {
    if (scorers.isNotEmpty) {
      score = scorers.fold<int>(0, (sum, runner) => sum + (runner.place ?? 0));
      split = (scorers.last.finishTime ?? Duration.zero) -
          (scorers.first.finishTime ?? Duration.zero);

      // Calculate average time with proper floating point division
      final totalDuration = scorers.fold(Duration.zero,
          (sum, runner) => sum + (runner.finishTime ?? Duration.zero));
      avgTime = Duration(
          milliseconds:
              (totalDuration.inMilliseconds / scorers.length).round());
    } else {
      score = 0;
      split = Duration.zero;
      avgTime = Duration.zero;
    }
  }
}
