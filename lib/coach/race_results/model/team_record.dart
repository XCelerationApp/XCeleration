import 'results_record.dart';

class TeamRecord {
  late int score;
  final String team;
  final String teamAbbreviation;
  late final List<ResultsRecord> scorers;
  late final List<ResultsRecord> nonScorers;
  final List<ResultsRecord> runners;
  int? place;
  late Duration split;
  late Duration avgTime;

  TeamRecord({
    required this.team,
    required this.teamAbbreviation,
    required this.runners,
    this.place,
  }) {
    nonScorers = runners;

    scorers = runners.length > 5 ? runners.take(5).toList() : [];
    updateStats();
  }

  List<ResultsRecord> get topSeven => runners.take(7).toList();

  factory TeamRecord.from(TeamRecord other) => TeamRecord(
        team: other.team,
        teamAbbreviation: other.teamAbbreviation,
        // Create deep copies of all runners to prevent reference issues
        runners: other.runners.map((r) => ResultsRecord.copy(r)).toList(),
        place: other.place,
      );

  void updateStats() {
    if (scorers.isNotEmpty) {
      score = scorers.fold<int>(0, (sum, runner) => sum + runner.place);
      split = scorers.last.finishTime - scorers.first.finishTime;
      avgTime = scorers.fold(
              Duration.zero, (sum, runner) => sum + runner.finishTime) ~/
          5;
    } else {
      score = 0;
      split = Duration.zero;
      avgTime = Duration.zero;
    }
  }
}
