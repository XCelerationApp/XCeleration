import 'runner.dart';
import 'team.dart';

class RaceRunner {
  final int raceId;
  final Runner runner;
  final Team team;

  RaceRunner({required this.raceId, required this.runner, required this.team});

  bool get isValid {
    return raceId > 0 &&
        runner.isValid &&
        team.isValid;
  }
}