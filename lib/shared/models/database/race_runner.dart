import 'runner.dart';
import 'team.dart';

class RaceRunner {
  final int raceId;
  final Runner runner;
  final Team team;

  RaceRunner({required this.raceId, required this.runner, required this.team});

  bool get isValid {
    return raceId > 0 && runner.isValid && team.isValid;
  }

  /// Create a deep copy of this RaceRunner
  RaceRunner copy() {
    return RaceRunner(
      raceId: raceId,
      runner: Runner(
        runnerId: runner.runnerId,
        uuid: runner.uuid,
        name: runner.name,
        grade: runner.grade,
        bibNumber: runner.bibNumber,
        createdAt: runner.createdAt,
        updatedAt: runner.updatedAt,
        deletedAt: runner.deletedAt,
        isDirty: runner.isDirty,
      ),
      team: Team(
        teamId: team.teamId,
        uuid: team.uuid,
        name: team.name,
        abbreviation: team.abbreviation,
        color: team.color,
        createdAt: team.createdAt,
        updatedAt: team.updatedAt,
        deletedAt: team.deletedAt,
        isDirty: team.isDirty,
      ),
    );
  }

  /// Factory to create a deep copy from another RaceRunner instance
  factory RaceRunner.from(RaceRunner other) {
    return other.copy();
  }
}
